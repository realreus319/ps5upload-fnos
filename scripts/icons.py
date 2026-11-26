# Generate simple original package icons without third-party dependencies.
import struct,zlib,pathlib
def png(n):
    rows=[]
    for y in range(n):
        row=bytearray()
        for x in range(n):
            u,v=x/n,y/n
            bg=(34,68,125,255)
            if ((u-.34)**2+(v-.52)**2 < .17**2 or (u-.66)**2+(v-.52)**2 < .17**2 or (.34<u<.66 and .35<v<.66)):
                bg=(239,245,255,255)
            if (.27<u<.40 and .49<v<.55) or (.31<u<.36 and .44<v<.60) or ((u-.67)**2+(v-.48)**2<.025**2) or ((u-.73)**2+(v-.55)**2<.025**2):
                bg=(34,68,125,255)
            row.extend(bg)
        rows.append(b'\0'+row)
    def chunk(t,d): return struct.pack('!I',len(d))+t+d+struct.pack('!I',zlib.crc32(t+d)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',n,n,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows)))+chunk(b'IEND',b'')
for path,n in [('ICON.PNG',64),('ICON_256.PNG',256),('app/ui/images/icon_64.png',64),('app/ui/images/icon_256.png',256)]:
    p=pathlib.Path(path);p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(png(n))
