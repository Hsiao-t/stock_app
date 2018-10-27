#!/usr/bin/py
"""
本模块包含公司治理数据相关函数
"""

import json
import requests as ro
from pandas import DataFrame
from random import randint


def limitedStock(year,month):
    """
    返回限售股信息，来源：东方财富网
    inputs:
        year: 解禁年份
        month: 解禁月份
    outputs:
        DataFrame
        sn,无意义
        code,股票代码
        market,股票市场，1为沪市，2为深市
        name, 名称
        date, 解禁日期
        ratio,解禁比例
        mktvalue, 解禁市值
        shares, 总股本
        c_shares, 流通股本
    
    """
    query = 'http://datainterface.eastmoney.com/EM_DataCenter/JS.aspx?type=FD&sty=BST&st=3&sr=true&fd={}&stat={}&js=[(x)]'.format(year,month)
    ct = ro.get(query).text
    js = json.loads(ct)
# limited-shares
    ls = [x.split(',') for x in js]
    df = DataFrame(data=ls,columns=['sn','code','market','name','date','count','ratio','close','mktvalue','shares','c_shares','a','b'])
    return df.iloc[:,:-2]

## 股东增持数据
## st=4 为一年内，stat=5为两年内, stat=3为半年内
def ggcg(count=3000,stat=3,sr='true'):
    """
    Todo: 返回最近一段时间股东持股变动情况
    Inputs:
        count，一次返回数量，默认3000
        stat, 时段，其中3为半年内，2为一季度，1为一个月，4为一年内，5为两年内
        sr, 'true'代表增持，'false'代表减持
    Outputs:
        DataFrame
        code, 股票代码
        name, 股票名称
        amount, 变动金额
        shares, 变动股数
        exprice, 变动均价
    """
    query='http://datainterface.eastmoney.com/EM_DataCenter/JS.aspx?type=GG&sty=ZCPHB&p=1&ps={}&js=[(pc),[(x)]]&sr={}&stat={}&st=1&rt={}'.format(count,sr,stat,randint(10000000,99999999))
    ct = ro.get(query).text
    js = json.loads(ct)
    js = js[1]
# limited-shares
    ls = [x.split(',') for x in js]
    df = DataFrame(data=ls,columns=['code','name','amount','shares','exprice','close','pc'])
    return df.iloc[:,:-2]

def lrfp(rp='2016-12-31',count=5000):
    """
    Todo: 返回利润分配数据
    Inputs:
        rp: 报告期
        count: 返回数量
    Outputs:
        DataFrame
        code, 股票代码
        name, 股票名称
        divmethods, 分配方法
        amounts, 分配金额
        dps, 每股红利（税前）
        dpr, 股息率
        eps, 每股收益
        rps, 每股未分配
        rps2, 上期每股未分配
        rdate, 股权登记日
        rpdate, 报告期
    """
    query = 'http://datainterface.eastmoney.com/EM_DataCenter/js.aspx?type=SR&sty=FHBL&fd={}&st=4&sr=-1&p=1&ps={}&js=[(pc),[(x)]]&rt={}'.format(rp,count,randint(10000000,99999999))
    ct = ro.get(query).text
    js = json.loads(ct)
    js = js[1]
# limited-shares
    ls = [x.split(',') for x in js]
    df = DataFrame(data=ls,columns=['code','name','method','inshare','divmethod','amounts','dps','dpr','eps','rps','rps2','rdate','pdate','rpdate'])
    return df.loc[:,['code','name','method','amounts','dps','dpr','eps','rps','rps2','rdate','rpdate']]