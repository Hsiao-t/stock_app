#!/usr/bin/py

import re
import requests as ro
from datetime import datetime

# 本函数用于将东财网下载的xls格式文本转为csv格式文本
# http://soft-f9.eastmoney.com/soft/gp18.php?code=60032301&exp=1
def Tick(f):
    def wrapper(*args,**kwargs):
        t0 = datetime.now()
        ret = f(*args,**kwargs)
        t1 = datetime.now()
        print((t1-t0).total_seconds())
        return ret
    return wrapper


def e2csv(ct):
    ct = ct.replace('&nbsp;','').replace('--','0.00').replace(',','').replace('\n','')
    ret=''
    rows = re.findall(r'<row.*?>(.*?)</row>',ct,re.S|re.I)
    for i in range(len(rows)):
        cells = re.findall(r'<data.*?>(.*?)</data>',rows[i],re.S|re.I)
        r = ','.join(cells)
        ret = ret + r + '\n'
    return ret


def webTable2csv(url,tid=0,th=1,rp=(',',''),encoding='utf8'):
    """
    # 获取网页上的表格数据
    # arg:tid 表格编号，从0开始
    # arg:th 是否包括<TH>标签内的数据
    # rp 进行预处理，默认为将','转为空字符串，因为','与csv文件格式冲突

    """
    ct=ro.get(url).content
    ct = ct.decode(encoding=encoding).replace(rp[0],rp[1])
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

def sw_class(url="http://localhost:8888/SwClass.csv"):
    """
    下载申万行业分类数据，这里先从申万官网下载完整数据（不知什么格式）使用Excl另存为csv格式并放在本地网站目录
    默认URL为从本地下载
    输入参数:
        url: 下载文件地址
    输出参数
        pandas.DataFrame, 下载的行业分类表
    注意：数据要保持最新则需要手动更新文件
    """
    from pandas import read_csv
    from requests import get
    from io import StringIO
    ct=get(url).text
    return read_csv(StringIO(ct),index_col=1).dropna(axis=1).ix[:,:2]

dsn = "postgresql://dbo:@localhost/stock_data"
def database_op(dsn,sql):
    """
    支持数据库: Postgresql 10+
    Inputs: 
      dsn,连接字符串
      sql,需要执行的命令
    Outputs:
      (rowcount,statusmessage)，执行结果
    """
    from psycopg2 import connect
    with connect(dsn) as con:
        with con.cursor() as rs:
            rs.execute(sql)
            rt = (rs.rowcount,rs.statusmessage,[]) if rs.rowcount == -1 else (rs.rowcount,rs.statusmessage,rs.fetchall())
    return rt
