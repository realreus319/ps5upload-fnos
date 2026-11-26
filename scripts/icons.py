import pathlib, subprocess
root=pathlib.Path(__file__).resolve().parents[1]
for path,n in [('ICON.PNG',64),('ICON_256.PNG',256),('app/ui/images/icon_64.png',64),('app/ui/images/icon_256.png',256)]:
    p=root/path
    p.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run(['rsvg-convert','-w',str(n),'-h',str(n),'-o',str(p),str(root/'branding/icon.svg')],check=True)
