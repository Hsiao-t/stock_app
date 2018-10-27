"""
本文件定义可获取资源列表
--url: 为获取资源网络地址，{}包括的内容为处理程序须传入参数
--lock: 资源内容提供者通常只允许同一IP获取一个资源，锁用于避免同一时刻有多个实例请求同一网站资源
"""
from fcntl import flock,LOCK_UN,LOCK_EX
from requests import get

def webload(url,lock,timeout=2):
  ret_cont = ""
  with open(lock,'w') as fpl:
    flock(fpl,LOCK_EX)
    ret_cont = get(url,lock,timeout=timeout).content 
    flock(fpl,LOCK_UN)
  return ret_cont

network_resources = {

  'cash_flow': { # 现金流量表数据
    'url':'http://quotes.money.163.com/service/xjllb_{}.html',
    'lock': '.Nf1.lock'
  },

  'balance_sheet': { # 资产负债表数据
    'url': 'http://quotes.money.163.com/service/zcfzb_{}.html',
    'lock': '.Nf1.lock'
  },

  'income_statement': { # 利润表数据
    'url': 'http://quotes.money.163.com/service/lrb_{}.html',
    'lock': '.Nf1.lock'
  },

  'board_of_directors': { # 董事会数据
    'url': 'http://quotes.money.163.com/service/gsgk.html?symbol={}&duty=dsh',
    'lock': '.Nf1.lock'
  },

  'board_of_supervisors': { # 监事会数据
    'url': 'http://quotes.money.163.com/service/gsgk.html?symbol={}&duty=jsh',
    'lock': '.Nf1.lock'
  },

  'management_layer': { # 管理层数据
    'url': 'http://quotes.money.163.com/service/gsgk.html?symbol={co}&duty=ggc',
    'lock': '.Nf1.lock'
  },

  'cons_expt': { # 一致预期数据
    'url': 'http://soft-f9.eastmoney.com/soft/gp63.php?code={}&exp=1',
    'lock': '.Nf2.lock'
  }

}
