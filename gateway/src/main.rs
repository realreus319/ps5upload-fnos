// fnOS Unix socket HTTP gateway and official engine supervisor.
use std::{convert::Infallible, env, fs, os::unix::fs::PermissionsExt, time::Duration};
use hyper::{body::{Bytes, Incoming}, header::{HeaderMap, HeaderName, HeaderValue}, Request, Response, StatusCode};
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper_util::rt::TokioIo;
use http_body_util::{BodyExt, Full, combinators::UnsyncBoxBody};
use tokio::net::{UnixListener, TcpStream};
use std::os::unix::fs::FileTypeExt;
use std::os::unix::process::CommandExt;
use tokio::process::{Child, Command};
use tokio::signal::unix::{signal, SignalKind};

type Body = UnsyncBoxBody<Bytes, hyper::Error>;
type Error = Box<dyn std::error::Error + Send + Sync>;

fn response(status: StatusCode, msg: &'static str) -> Response<Body> {
    Response::builder().status(status)
        .body(Full::new(Bytes::from_static(msg.as_bytes())).map_err(|never: Infallible| match never {}).boxed_unsync()).unwrap()
}

fn clean_hop_headers(h: &mut HeaderMap, upgrade: bool) {
    let nominated: Vec<HeaderName> = h.get_all("connection").iter()
        .filter_map(|v| v.to_str().ok()).flat_map(|s| s.split(','))
        .filter_map(|s| HeaderName::from_bytes(s.trim().as_bytes()).ok()).collect();
    for key in nominated {
        if !(upgrade && key.as_str() == "upgrade") { h.remove(key); }
    }
    for key in ["connection", "proxy-connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailer", "transfer-encoding"] { h.remove(key); }
    if upgrade { h.insert("connection", HeaderValue::from_static("upgrade")); }
    else { h.remove("upgrade"); }
}

async fn forward(mut req: Request<Incoming>, target: String) -> Result<Response<Body>, Error> {
    if req.headers().get("x-trim-isadmin").and_then(|x| x.to_str().ok()) != Some("true") {
        return Ok(response(StatusCode::FORBIDDEN, "Forbidden"));
    }
    if req.uri().path() == "/app/ps5upload" {
        let mut r = response(StatusCode::PERMANENT_REDIRECT, "");
        r.headers_mut().insert("location", HeaderValue::from_static("/app/ps5upload/"));
        return Ok(r);
    }
    if !req.uri().path().starts_with("/app/ps5upload/") || req.uri().authority().is_some() {
        return Ok(response(StatusCode::NOT_FOUND, "Not found"));
    }
    let websocket = req.headers().get("upgrade").and_then(|v| v.to_str().ok()).map(|s| s.eq_ignore_ascii_case("websocket")).unwrap_or(false)
        && req.headers().get_all("connection").iter().filter_map(|v| v.to_str().ok())
           .any(|s| s.split(',').any(|v| v.trim().eq_ignore_ascii_case("upgrade")));
    let incoming_upgrade = if websocket { Some(hyper::upgrade::on(&mut req)) } else { None };
    clean_hop_headers(req.headers_mut(), websocket);
    for key in ["x-trim-isadmin", "x-trim-userid", "x-trim-username", "x-forwarded-host", "x-forwarded-for", "x-forwarded-proto"] {
        req.headers_mut().remove(key);
    }
    let io = tokio::time::timeout(Duration::from_secs(10), TcpStream::connect(&target)).await??;
    let (mut sender, conn) = hyper::client::conn::http1::handshake(TokioIo::new(io)).await?;
    tokio::spawn(async move { let _ = conn.with_upgrades().await; });
    let mut res = sender.send_request(req).await?;
    if websocket && res.status() == StatusCode::SWITCHING_PROTOCOLS {
        let outgoing_upgrade = hyper::upgrade::on(&mut res);
        if let Some(incoming) = incoming_upgrade {
            tokio::spawn(async move {
                if let Ok((a,b)) = tokio::try_join!(incoming, outgoing_upgrade) {
                    let (mut a,mut b) = (TokioIo::new(a), TokioIo::new(b));
                    let _ = tokio::io::copy_bidirectional(&mut a,&mut b).await;
                }
            });
        }
        clean_hop_headers(res.headers_mut(), true);
    } else {
        clean_hop_headers(res.headers_mut(), false);
    }
    Ok(res.map(|b| b.boxed_unsync()))
}

async fn serve(listener: UnixListener, target: String) -> Result<(), Error> {
    loop {
        let (stream, _) = listener.accept().await?;
        let target = target.clone();
        tokio::spawn(async move {
            let svc = service_fn(move |r| {
                let target = target.clone();
                async move {
                    Ok::<_, Infallible>(forward(r, target).await.unwrap_or_else(|_| response(StatusCode::BAD_GATEWAY, "Bad gateway")))
                }
            });
            let _ = http1::Builder::new().serve_connection(TokioIo::new(stream),svc).with_upgrades().await;
        });
    }
}

fn bind_socket(path: &str) -> Result<UnixListener, Error> {
    match fs::symlink_metadata(path) {
        Ok(m) if m.file_type().is_socket() => {
            if std::os::unix::net::UnixStream::connect(path).is_ok() {
                return Err("gateway socket already active".into());
            }
            fs::remove_file(path)?;
        }
        Ok(_) => return Err("gateway path exists and is not a socket".into()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {},
        Err(e) => return Err(e.into()),
    }
    let listener = UnixListener::bind(path)?;
    fs::set_permissions(path, fs::Permissions::from_mode(0o660))?;
    Ok(listener)
}

// The root supervisor never listens on a network/socket or modifies mounted files.
fn parse_id(name: &str, fallback: u32) -> Result<u32, Error> {
    match env::var(name) {
        Ok(v) if !v.is_empty() => {
            if !v.bytes().all(|b| b.is_ascii_digit()) { return Err(format!("invalid {name}: use a nonzero numeric ID").into()); }
            let n: u32 = v.parse()?;
            if n == 0 || n > 2147483647 { return Err(format!("invalid {name}: ID must be 1..2147483647").into()); }
            Ok(n)
        }
        _ => Ok(fallback),
    }
}

fn spawn_as(program: &str, args: &[String], uid: u32, gid: u32, extra_gid: Option<u32>) -> Result<Child, Error> {
    let mut c = std::process::Command::new(program);
    c.args(args);
    // Clear inherited root groups, then drop GID and UID before exec.
    unsafe {
        c.pre_exec(move || {
            let groups = [extra_gid.unwrap_or(gid) as libc::gid_t];
            if libc::setgroups(1, groups.as_ptr()) != 0
                || libc::setgid(gid as libc::gid_t) != 0
                || libc::setuid(uid as libc::uid_t) != 0 {
                return Err(std::io::Error::last_os_error());
            }
            Ok(())
        });
    }
    Ok(Command::from(c).kill_on_drop(true).spawn()?)
}

async fn stop_child(c: &mut Child) -> Result<(), Error> {
    if let Some(pid) = c.id() { unsafe { libc::kill(pid as i32, libc::SIGTERM); } }
    if tokio::time::timeout(Duration::from_secs(5), c.wait()).await.is_err() {
        c.kill().await?;
    }
    Ok(())
}

async fn supervise(args: &[String]) -> Result<(), Error> {
    if args.len() < 3 { return Err("usage: --supervise SOCKET TARGET ENGINE".into()); }
    let pkg_uid = parse_id("FNOS_PACKAGE_UID", 65532)?;
    let pkg_gid = parse_id("FNOS_PACKAGE_GID", 65532)?;
    let custom = env::var("FNOS_CUSTOM_DATA").map(|s| !s.is_empty()).unwrap_or(false);
    let uid = parse_id("FNOS_ENGINE_UID", if custom { 1000 } else { pkg_uid })?;
    let gid = parse_id("FNOS_ENGINE_GID", if custom { 1000 } else { pkg_gid })?;
    let mut term = signal(SignalKind::terminate())?;
    let mut int = signal(SignalKind::interrupt())?;
    eprintln!("fnOS supervisor: gateway {pkg_uid}:{pkg_gid}; engine {uid}:{gid}");
    let exe = env::current_exe()?;
    let exe = exe.to_str().ok_or("invalid gateway executable path")?;
    let mut gateway = spawn_as(exe, &args[..2], pkg_uid, pkg_gid, None)?;
    let mut engine = match spawn_as(&args[2], &args[3..], uid, gid, Some(pkg_gid)) {
        Ok(c) => c,
        Err(e) => { let _ = stop_child(&mut gateway).await; return Err(e); }
    };
    let unexpected = tokio::select! {
        s = gateway.wait() => Some(format!("gateway exited: {s:?}")),
        s = engine.wait() => Some(format!("engine exited: {s:?}")),
        _ = term.recv() => None,
        _ = int.recv() => None,
    };
    let (a,b) = tokio::join!(stop_child(&mut gateway), stop_child(&mut engine));
    a?; b?;
    if let Some(e) = unexpected { return Err(e.into()); }
    Ok(())
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<(), Error> {
    let args: Vec<String> = env::args().collect();
    if args.get(1).map(String::as_str) == Some("--supervise") { return supervise(&args[2..]).await; }
    let socket = args.get(1).ok_or("usage: gateway-rust SOCKET TARGET [ENGINE]")?;
    let target = args.get(2).cloned().unwrap_or_else(|| "127.0.0.1:19113".into());
    let mut term = signal(SignalKind::terminate())?;
    let mut int = signal(SignalKind::interrupt())?;
    let listener = bind_socket(socket)?;
    let mut gateway = tokio::spawn(serve(listener,target));
    let result: Result<(),Error> = async {
        if let Some(engine) = args.get(3) {
            let mut child = tokio::process::Command::new(engine).args(&args[4..]).kill_on_drop(true).spawn()?;
            let status = tokio::select! {
                s = child.wait() => Some(s?),
                _ = term.recv() => None,
                _ = int.recv() => None,
                r = &mut gateway => {
                    eprintln!("gateway stopped: {r:?}");
                    None
                }
            };
            if let Some(s) = status {
                return Err(format!("engine exited: {s}").into());
            }
            if let Some(pid) = child.id() { unsafe { libc::kill(pid as i32, libc::SIGTERM); } }
            if tokio::time::timeout(Duration::from_secs(8), child.wait()).await.is_err() {
                child.kill().await?;
            }
        } else {
            tokio::select! {
                _ = term.recv() => {},
                _ = int.recv() => {},
                r = &mut gateway => { r??; return Err("gateway stopped".into()); }
            }
        }
        Ok(())
    }.await;
    gateway.abort();
    let _ = fs::remove_file(socket);
    result
}
