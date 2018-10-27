# 目录结构
./bin/ --可执行文件
./sbin/ --可执行文件，需要root运行
./conf/ --配置文件目录
./log/ --日志文件目录
./modules/ --模块
./doc/ --文档目录

# 采集程序
./bin/csrc_idst --获取证监会行业数据并保存至数据库"_csrc"表
./bin/store_rpt --保存财务报表
./bin/get_rpt --下载财务报表至 data/stockf 目录
./bin/cons_data --获取一致预期数据，并保存至数据库"_cons_data"表
./bin/inst_data --机构预测数据，来源：东方财富网
./bin/bod_data --董监高数据，来源：东方财富网
./bin/stock_va --获取当日市场数据并保存数据库"_tbl_va"表

# 调用链
./sbin/inst-serv
./bin/get_rpt --force
./bin/inst_data
./bin/cons_data
./bin/bod_data
./bin/stock_va
./bin/refresh_mat_views stock_data dbo
./bin/store_rpt
--> ./bin/refresh_mat_views stock_data dbo

# 安装程序
-- 本程序需要crond程序进行任务调试，安装程序位于sbin/inst-serv
-- 安装命令 ./sbin/inst-serv reload

