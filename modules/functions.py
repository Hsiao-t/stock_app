from datetime import datetime
import json

def logg(f,msg):
    now = str(datetime.now())
    msg = now + ': ' + msg + '\n'
    with open(f,'a+') as fp:
        fp.write(msg)

def load_cfg(f):
    with open(f) as fp:
        conf = json.load(fp)
    return conf
