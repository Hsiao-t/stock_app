# 检查程序所需环境

import os,sys
from datetime import datetime

def check_requirements():
    global tsu, json, pandas, os, sys, datetime, ro, read_csv, connect, create_engine
    try:
        import tushare as tsu
    except:
        print('run "pip install tushare" to install tushare lib.')
    try:
        import json as json
    except:
        print('exception: no json lib found.')
    try:
        import pandas as pandas
        from pandas import read_csv
    except:
        print('run "pip install pandas" to install pandas lib.')
    try:
        import requests as ro
    except:
        print('run "pip install requests" to install requests lib.')
    try:
        from psycopg2 import connect
    except:
        print('run "pip install psycopg2" to install postgresql driver.')
    try:
        from sqlalchemy import create_engine
    except:
        print('run "pip install sqlalchemy" to install sqlalchemy.')
