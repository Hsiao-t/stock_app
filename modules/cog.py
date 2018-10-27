import re
import requests as ro
from pandas import concat
from fcntl import flock,LOCK_EX,LOCK_UN

def webTable2csv(url,tid=0,th=1,rp=(',',''),rlock=None):
  """
  # 获取网页上的表格数据
  # arg:tid 表格编号，从0开始
  # arg:th 是否包括<TH>标签内的数据
  # rp 进行预处理，默认为将','转为空字符串，因为','与csv文件格式冲突
  # rlock: 资源锁，如果有则加锁，没有则直接获取

  """
  if rlock is None:
    ct=ro.get(url).text.replace(rp[0],rp[1])
  else:
    with open(rlock,'w') as fpl:
      flock(fpl,LOCK_EX)
      ct=ro.get(url).text.replace(rp[0],rp[1])
      flock(fpl,LOCK_UN)
  ct = re.sub(r'<!--.*?-->','',ct)
  ct = re.sub(r'\s+','',ct)
  if th==1:
    td = r'<t(?:d|h).*?>(.*?)</t(?:d|h)>'
  else:
    td = r'<td.*?>(.*?)</td>'
  tables = re.findall(r'<table.*?>(.*?)</table>',ct,18)
  rows = re.findall(r'<tr.*?>(.*?)</tr>',tables[tid],18)
  ret = ''
  for c in rows:
    ret=ret+','.join(re.findall(td,c,18))+'\n'
  return ret

# typ = dsh|jsh|ggc
def bod(code='600660',typ='dsh'):
  """
  # 获取董事会、监事会、高级管理层持股及报酬
  # input:
  # code: 证券代码
  # typ: 类型、dsh=董事会，jsh=监事会，ggc=管理层
  # output:
  # pandas.DataFrame, columns=
  """
  query='http://quotes.money.163.com/service/gsgk.html?symbol={co}&duty={t}'.format(co=code,t=typ)
  from io import StringIO as sio
  from pandas import read_csv
  return read_csv(sio(webTable2csv(query).replace('--','0')))

def bod_all(code):
  dsh = bod(code=code,typ='dsh')
  dsh = dsh.drop_duplicates('姓名',keep='first')
  jsh = bod(code=code,typ='jsh')
  jsh = jsh.drop_duplicates('姓名',keep='first')
  ggc = bod(code=code,typ='ggc').drop_duplicates('姓名',keep='first')
  rt = concat([dsh,jsh,ggc])
  rt['股票代码'] = [str(code)]*len(rt)
  rt = rt.loc[:,['股票代码','姓名','职务','持股数','报酬','起止时间']]
  return rt
