--
-- PostgreSQL database dump
--

-- Dumped from database version 10.0
-- Dumped by pg_dump version 10.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: any_q4(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION any_q4(b_date text, n integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
 -- 本程序返回当前日期向前最近一次年度报告期
 declare
   cur_year int;
   cur_month int;
   day int;
 begin
   cur_year := to_char(b_date::date,'YYYY');
   cur_month := to_char(b_date::date,'MM');
   day := to_char(b_date::date,'DD');
   if cur_month = 12 and day = 31 then
     cur_year := cur_year + n;
   else
     cur_year := cur_year + n - 1;
     cur_month := 12;
     day := 31;
   end if;

   return cur_year::text || '-' || '12-31';

  end

$$;


--
-- Name: eofm(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION eofm(b_date text, x_months integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
-- 本函数返回日期字符串相差N个月的的最后一天，等同于Excel,eomonth函数
  declare
    cur_year int;
    cur_month int;
    new_month int;
    new_month_t text;
    new_year int;
    day int;
    all_month int;
  begin
    cur_year := to_char(b_date::date,'YYYY')::int;
    cur_month := to_char(b_date::date,'MM')::int;
    all_month := cur_year * 12 + x_months + cur_month;
    if all_month % 12 = 0 then
      new_month := 12;
      new_year := all_month / 12 - 1;
    else
      new_month := all_month % 12;
      new_year := all_month / 12;
    end if;
   
    if new_month = 2 then
      if ((new_year%100!=0 and new_year%4=0) or (new_year%400=0)) then day := 29;
      else day := 28;
      end if;
    elseif new_month in (1,3,5,7,8,10,12) then day := 31;
    else day := 30;
    end if;
    if new_month < 10 then new_month_t := '0' || new_month::text;
    else new_month_t := new_month::text;
    end if;

    return new_year::text || '-' ||  new_month_t || '-' || day::text;

  end

$$;


--
-- Name: my_div(numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION my_div(numeric, numeric) RETURNS numeric
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
select case when $2 <> 0 or $2 is null then $1/$2 else 0.0 end ;
$_$;


--
-- Name: //; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR // (
    PROCEDURE = my_div,
    LEFTARG = numeric,
    RIGHTARG = numeric
);


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: _bod_all; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE _bod_all (
    "股票代码" integer,
    "姓名" text,
    "职务" text,
    "持股数" numeric,
    "报酬" numeric,
    "起止时间" text
);


--
-- Name: _bod_summ; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW _bod_summ AS
 SELECT _bod_all."股票代码" AS code,
    sum(_bod_all."持股数") AS shares,
    sum(_bod_all."报酬") AS salaries
   FROM _bod_all
  GROUP BY _bod_all."股票代码";


--
-- Name: raw_cf; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE raw_cf (
    id integer NOT NULL,
    rp text,
    c_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    code integer,
    data jsonb
);


--
-- Name: raw_is; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE raw_is (
    id integer NOT NULL,
    rp text,
    c_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    code integer,
    data jsonb
);


--
-- Name: _cashflows_q4; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _cashflows_q4 AS
 SELECT raw_is.code AS "股票代码",
    any_q4(raw_is.rp, 0) AS "最新年报",
    round((((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric + (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric) + (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric), 4) AS "三年净利润",
    round((((((raw_cf.data -> '经营活动产生的现金流量净额(万元)'::text) ->> any_q4(raw_cf.rp, 0)))::numeric + (((raw_cf.data -> '经营活动产生的现金流量净额(万元)'::text) ->> any_q4(raw_cf.rp, '-1'::integer)))::numeric) + (((raw_cf.data -> '经营活动产生的现金流量净额(万元)'::text) ->> any_q4(raw_cf.rp, '-2'::integer)))::numeric), 4) AS "三年经营现金流",
    (('-1'::integer)::numeric * round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric - (((raw_cf.data -> '经营活动产生的现金流量净额(万元)'::text) ->> any_q4(raw_cf.rp, 0)))::numeric), 4)) AS "现金流减利润",
    (('-1'::integer)::numeric * round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric - (((raw_cf.data -> '经营活动产生的现金流量净额(万元)'::text) ->> any_q4(raw_cf.rp, '-1'::integer)))::numeric), 4)) AS "现金流减利润1",
    (('-1'::integer)::numeric * round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric - (((raw_cf.data -> '经营活动产生的现金流量净额(万元)'::text) ->> any_q4(raw_cf.rp, '-2'::integer)))::numeric), 4)) AS "现金流减利润2",
    (('-1'::integer)::numeric * round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric - (((raw_cf.data -> '经营活动产生的现金流量净额(万元)'::text) ->> any_q4(raw_cf.rp, '-3'::integer)))::numeric), 4)) AS "现金流减利润3",
    (('-1'::integer)::numeric * round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric - (((raw_cf.data -> '经营活动产生的现金流量净额(万元)'::text) ->> any_q4(raw_cf.rp, '-4'::integer)))::numeric), 4)) AS "现金流减利润4"
   FROM raw_is,
    raw_cf
  WHERE (raw_cf.code = raw_is.code)
  WITH NO DATA;


--
-- Name: raw_bs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE raw_bs (
    id integer NOT NULL,
    rp text,
    c_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    code integer,
    data jsonb
);


--
-- Name: _cog_q4a; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _cog_q4a AS
 SELECT raw_is.code AS "股票代码",
    any_q4(raw_is.rp, 0) AS "最新年报",
    (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "净利润",
    (((raw_is.data -> '管理费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "管理费用",
    (((raw_is.data -> '少数股东损益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "少数股东损益",
    (((raw_bs.data -> '少数股东权益(万元)'::text) ->> any_q4(raw_bs.rp, 0)))::numeric AS "少数股东权益",
    (((raw_bs.data -> '其他应收款(万元)'::text) ->> any_q4(raw_bs.rp, 0)))::numeric AS "其他应收款",
    (((raw_bs.data -> '其他应付款(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "其他应付款",
    ((((((raw_cf.data -> '分配股利、利润或偿付利息所支付的现金(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric - (((raw_cf.data -> '其中：子公司支付给少数股东的股利、利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric) - (((raw_is.data -> '财务费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric) + (((raw_cf.data -> '汇率变动对现金及现金等价物的影响(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric) AS "当前股利",
    ((((((((raw_cf.data -> '分配股利、利润或偿付利息所支付的现金(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric - (((raw_cf.data -> '其中：子公司支付给少数股东的股利、利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric) - (((raw_is.data -> '财务费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric) + (((raw_cf.data -> '汇率变动对现金及现金等价物的影响(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric) + ((((((raw_cf.data -> '分配股利、利润或偿付利息所支付的现金(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric - (((raw_cf.data -> '其中：子公司支付给少数股东的股利、利润(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric) - (((raw_is.data -> '财务费用(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric) + (((raw_cf.data -> '汇率变动对现金及现金等价物的影响(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric)) + ((((((raw_cf.data -> '分配股利、利润或偿付利息所支付的现金(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric - (((raw_cf.data -> '其中：子公司支付给少数股东的股利、利润(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric) - (((raw_is.data -> '财务费用(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric) + (((raw_cf.data -> '汇率变动对现金及现金等价物的影响(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric)) AS "三年累积股利",
    ((((((raw_cf.data -> '吸收投资收到的现金(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric - (((raw_cf.data -> '其中：子公司吸收少数股东投资收到的现金(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric) + ((((raw_cf.data -> '吸收投资收到的现金(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric - (((raw_cf.data -> '其中：子公司吸收少数股东投资收到的现金(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric)) + ((((raw_cf.data -> '吸收投资收到的现金(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric - (((raw_cf.data -> '其中：子公司吸收少数股东投资收到的现金(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric)) AS "股权融资",
    (((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric + (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric) + (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric) AS "三年净利",
    round(((((raw_bs.data -> '实收资本(或股本)(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_bs.data -> '实收资本(或股本)(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric), 2) AS "股本变动倍数"
   FROM raw_cf,
    raw_is,
    raw_bs
  WHERE ((raw_cf.code = raw_is.code) AND (raw_cf.code = raw_bs.code))
  WITH NO DATA;


--
-- Name: _cons_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE _cons_data (
    id integer NOT NULL,
    code integer,
    update timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    data jsonb
);


--
-- Name: TABLE _cons_data; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE _cons_data IS '一致预期数据';


--
-- Name: _cons_data_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE _cons_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: _cons_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE _cons_data_id_seq OWNED BY _cons_data.id;


--
-- Name: _cost_mrq; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _cost_mrq AS
 SELECT raw_is.code AS "股票代码",
    raw_is.rp AS "报告期",
    round(((((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "营业总收入",
    round(((((raw_is.data -> '营业收入(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "营业收入",
    round(((((raw_is.data -> '营业总成本(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "营业总成本",
    round(((((raw_is.data -> '营业成本(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "营业成本",
    round(((((raw_is.data -> '管理费用(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "管理费用",
    round(((((raw_is.data -> '销售费用(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "销售费用",
    round(((((raw_is.data -> '财务费用(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "财务费用",
    round(((((raw_is.data -> '资产减值损失(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "资产减值",
    round(((((raw_is.data -> '营业税金及附加(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "营业税金",
    round(((((raw_is.data -> '投资收益(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "投资收益",
    round(((((raw_is.data -> '公允价值变动收益(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "公允价值变动",
    round(((((raw_is.data -> '营业外收入(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "营业外收入",
    round(((((raw_is.data -> '营业外支出(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "营业外支出",
    round(((((raw_is.data -> '利润总额(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "利润总额",
    round(((((raw_is.data -> '所得税费用(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "所得税",
    round(((((raw_is.data -> '净利润(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "净利润",
    round(((((raw_is.data -> '少数股东损益(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "少数股东损益",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric), 4) AS "归母净利润"
   FROM raw_is
  WITH NO DATA;


--
-- Name: _cost_q4a; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _cost_q4a AS
 SELECT raw_is.code AS "股票代码",
    any_q4(raw_is.rp, 0) AS "报告期",
    round(((((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "营业总收入",
    round(((((raw_is.data -> '营业收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "营业收入",
    round(((((raw_is.data -> '营业总成本(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "营业总成本",
    round(((((raw_is.data -> '营业成本(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "营业成本",
    round(((((raw_is.data -> '管理费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "管理费用",
    round(((((raw_is.data -> '销售费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "销售费用",
    round(((((raw_is.data -> '财务费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "财务费用",
    round(((((raw_is.data -> '资产减值损失(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "资产减值",
    round(((((raw_is.data -> '营业税金及附加(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "营业税金",
    round(((((raw_is.data -> '投资收益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "投资收益",
    round(((((raw_is.data -> '公允价值变动收益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "公允价值变动",
    round(((((raw_is.data -> '营业外收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "营业外收入",
    round(((((raw_is.data -> '营业外支出(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "营业外支出",
    round(((((raw_is.data -> '利润总额(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "利润总额",
    round(((((raw_is.data -> '所得税费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "所得税",
    round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "净利润",
    round(((((raw_is.data -> '少数股东损益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "少数股东损益",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric), 4) AS "归母净利润"
   FROM raw_is
  WITH NO DATA;


--
-- Name: _csrc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE _csrc (
    code integer,
    name text,
    class_code text,
    class_name text,
    idst_code text,
    idst_name text
);


--
-- Name: TABLE _csrc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE _csrc IS '证监会行业数据';


--
-- Name: _data_stats; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW _data_stats AS
 SELECT raw_bs.code,
    raw_bs.rp AS bsrp,
    raw_is.rp AS isrp,
    raw_cf.rp AS cfrp
   FROM raw_bs,
    raw_is,
    raw_cf
  WHERE ((raw_bs.code = raw_is.code) AND (raw_bs.code = raw_cf.code));


--
-- Name: _growth_report_mrq; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _growth_report_mrq AS
 SELECT raw_is.code AS "股票代码",
    raw_is.rp AS "报告期",
    (round(((((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> eofm(raw_is.rp, '-12'::integer)))::numeric), 4) - (1)::numeric) AS "营收同比",
    (round(((||/ (((((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> eofm(raw_is.rp, '-36'::integer)))::numeric))::double precision))::numeric, 4) - (1)::numeric) AS "营收复合",
    (round(((((raw_is.data -> '净利润(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> eofm(raw_is.rp, '-12'::integer)))::numeric), 4) - (1)::numeric) AS "利润同比",
    (round(((||/ (((((raw_is.data -> '净利润(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> eofm(raw_is.rp, '-36'::integer)))::numeric))::double precision))::numeric, 4) - (1)::numeric) AS "利润复合"
   FROM raw_is
  WITH NO DATA;


--
-- Name: _growth_report_q4; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _growth_report_q4 AS
 SELECT raw_is.code AS "股票代码",
    any_q4(raw_is.rp, 0) AS "最新年报",
    (round(((((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric), 4) - (1)::numeric) AS "营收同比",
    (round(((||/ (((((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric))::double precision))::numeric, 4) - (1)::numeric) AS "营收复合",
    (round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric), 4) - (1)::numeric) AS "利润同比",
    (round(((||/ (((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric))::double precision))::numeric, 4) - (1)::numeric) AS "利润复合"
   FROM raw_is
  WITH NO DATA;


--
-- Name: _income_mrqa; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _income_mrqa AS
 SELECT raw_is.code AS "股票代码",
    raw_is.rp AS "报告期",
    (((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric AS "营业总收入",
    (((raw_is.data -> '营业收入(万元)'::text) ->> raw_is.rp))::numeric AS "营业收入",
    (((raw_is.data -> '营业总成本(万元)'::text) ->> raw_is.rp))::numeric AS "营业总成本",
    (((raw_is.data -> '营业成本(万元)'::text) ->> raw_is.rp))::numeric AS "营业成本",
    (((raw_is.data -> '管理费用(万元)'::text) ->> raw_is.rp))::numeric AS "管理费用",
    (((raw_is.data -> '销售费用(万元)'::text) ->> raw_is.rp))::numeric AS "销售费用",
    (((raw_is.data -> '财务费用(万元)'::text) ->> raw_is.rp))::numeric AS "财务费用",
    (((raw_is.data -> '资产减值损失(万元)'::text) ->> raw_is.rp))::numeric AS "资产减值",
    (((raw_is.data -> '营业税金及附加(万元)'::text) ->> raw_is.rp))::numeric AS "营业税金",
    (((raw_is.data -> '投资收益(万元)'::text) ->> raw_is.rp))::numeric AS "投资收益",
    (((raw_is.data -> '公允价值变动收益(万元)'::text) ->> raw_is.rp))::numeric AS "公允价值变动",
    (((raw_is.data -> '营业外收入(万元)'::text) ->> raw_is.rp))::numeric AS "营业外收入",
    (((raw_is.data -> '营业外支出(万元)'::text) ->> raw_is.rp))::numeric AS "营业外支出",
    (((raw_is.data -> '利润总额(万元)'::text) ->> raw_is.rp))::numeric AS "利润总额",
    (((raw_is.data -> '所得税费用(万元)'::text) ->> raw_is.rp))::numeric AS "所得税",
    (((raw_is.data -> '净利润(万元)'::text) ->> raw_is.rp))::numeric AS "净利润",
    (((raw_is.data -> '少数股东损益(万元)'::text) ->> raw_is.rp))::numeric AS "少数股东损益",
    (((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> raw_is.rp))::numeric AS "归母净利润",
    (((raw_is.data -> '基本每股收益'::text) ->> raw_is.rp))::numeric AS "基本每股收益"
   FROM raw_is
  WITH NO DATA;


--
-- Name: _income_q4; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _income_q4 AS
 SELECT raw_is.code AS "股票代码",
    any_q4(raw_is.rp, 0) AS "报告期",
    (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业总收入",
    (((raw_is.data -> '营业收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业收入",
    (((raw_is.data -> '营业总成本(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业总成本",
    (((raw_is.data -> '营业成本(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业成本",
    (((raw_is.data -> '管理费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "管理费用",
    (((raw_is.data -> '销售费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "销售费用",
    (((raw_is.data -> '财务费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "财务费用",
    (((raw_is.data -> '资产减值损失(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "资产减值",
    (((raw_is.data -> '营业税金及附加(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业税金",
    (((raw_is.data -> '投资收益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "投资收益",
    (((raw_is.data -> '公允价值变动收益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "公允价值变动",
    (((raw_is.data -> '营业外收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业外收入",
    (((raw_is.data -> '营业外支出(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业外支出",
    (((raw_is.data -> '利润总额(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "利润总额",
    (((raw_is.data -> '所得税费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "所得税",
    (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "净利润",
    (((raw_is.data -> '少数股东损益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "少数股东损益",
    (((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "归母净利润",
    (((raw_is.data -> '基本每股收益'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "基本每股收益"
   FROM raw_is
UNION
 SELECT raw_is.code AS "股票代码",
    any_q4(raw_is.rp, '-1'::integer) AS "报告期",
    (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "营业总收入",
    (((raw_is.data -> '营业收入(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "营业收入",
    (((raw_is.data -> '营业总成本(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "营业总成本",
    (((raw_is.data -> '营业成本(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "营业成本",
    (((raw_is.data -> '管理费用(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "管理费用",
    (((raw_is.data -> '销售费用(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "销售费用",
    (((raw_is.data -> '财务费用(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "财务费用",
    (((raw_is.data -> '资产减值损失(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "资产减值",
    (((raw_is.data -> '营业税金及附加(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "营业税金",
    (((raw_is.data -> '投资收益(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "投资收益",
    (((raw_is.data -> '公允价值变动收益(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "公允价值变动",
    (((raw_is.data -> '营业外收入(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "营业外收入",
    (((raw_is.data -> '营业外支出(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "营业外支出",
    (((raw_is.data -> '利润总额(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "利润总额",
    (((raw_is.data -> '所得税费用(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "所得税",
    (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "净利润",
    (((raw_is.data -> '少数股东损益(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "少数股东损益",
    (((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "归母净利润",
    (((raw_is.data -> '基本每股收益'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric AS "基本每股收益"
   FROM raw_is
UNION
 SELECT raw_is.code AS "股票代码",
    any_q4(raw_is.rp, '-2'::integer) AS "报告期",
    (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "营业总收入",
    (((raw_is.data -> '营业收入(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "营业收入",
    (((raw_is.data -> '营业总成本(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "营业总成本",
    (((raw_is.data -> '营业成本(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "营业成本",
    (((raw_is.data -> '管理费用(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "管理费用",
    (((raw_is.data -> '销售费用(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "销售费用",
    (((raw_is.data -> '财务费用(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "财务费用",
    (((raw_is.data -> '资产减值损失(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "资产减值",
    (((raw_is.data -> '营业税金及附加(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "营业税金",
    (((raw_is.data -> '投资收益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "投资收益",
    (((raw_is.data -> '公允价值变动收益(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "公允价值变动",
    (((raw_is.data -> '营业外收入(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "营业外收入",
    (((raw_is.data -> '营业外支出(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "营业外支出",
    (((raw_is.data -> '利润总额(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "利润总额",
    (((raw_is.data -> '所得税费用(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "所得税",
    (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "净利润",
    (((raw_is.data -> '少数股东损益(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "少数股东损益",
    (((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "归母净利润",
    (((raw_is.data -> '基本每股收益'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric AS "基本每股收益"
   FROM raw_is
UNION
 SELECT raw_is.code AS "股票代码",
    any_q4(raw_is.rp, '-3'::integer) AS "报告期",
    (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "营业总收入",
    (((raw_is.data -> '营业收入(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "营业收入",
    (((raw_is.data -> '营业总成本(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "营业总成本",
    (((raw_is.data -> '营业成本(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "营业成本",
    (((raw_is.data -> '管理费用(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "管理费用",
    (((raw_is.data -> '销售费用(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "销售费用",
    (((raw_is.data -> '财务费用(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "财务费用",
    (((raw_is.data -> '资产减值损失(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "资产减值",
    (((raw_is.data -> '营业税金及附加(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "营业税金",
    (((raw_is.data -> '投资收益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "投资收益",
    (((raw_is.data -> '公允价值变动收益(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "公允价值变动",
    (((raw_is.data -> '营业外收入(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "营业外收入",
    (((raw_is.data -> '营业外支出(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "营业外支出",
    (((raw_is.data -> '利润总额(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "利润总额",
    (((raw_is.data -> '所得税费用(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "所得税",
    (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "净利润",
    (((raw_is.data -> '少数股东损益(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "少数股东损益",
    (((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "归母净利润",
    (((raw_is.data -> '基本每股收益'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric AS "基本每股收益"
   FROM raw_is
UNION
 SELECT raw_is.code AS "股票代码",
    any_q4(raw_is.rp, '-4'::integer) AS "报告期",
    (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "营业总收入",
    (((raw_is.data -> '营业收入(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "营业收入",
    (((raw_is.data -> '营业总成本(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "营业总成本",
    (((raw_is.data -> '营业成本(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "营业成本",
    (((raw_is.data -> '管理费用(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "管理费用",
    (((raw_is.data -> '销售费用(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "销售费用",
    (((raw_is.data -> '财务费用(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "财务费用",
    (((raw_is.data -> '资产减值损失(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "资产减值",
    (((raw_is.data -> '营业税金及附加(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "营业税金",
    (((raw_is.data -> '投资收益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "投资收益",
    (((raw_is.data -> '公允价值变动收益(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "公允价值变动",
    (((raw_is.data -> '营业外收入(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "营业外收入",
    (((raw_is.data -> '营业外支出(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "营业外支出",
    (((raw_is.data -> '利润总额(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "利润总额",
    (((raw_is.data -> '所得税费用(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "所得税",
    (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "净利润",
    (((raw_is.data -> '少数股东损益(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "少数股东损益",
    (((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "归母净利润",
    (((raw_is.data -> '基本每股收益'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric AS "基本每股收益"
   FROM raw_is
  WITH NO DATA;


--
-- Name: _income_q4a; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _income_q4a AS
 SELECT raw_is.code AS "股票代码",
    any_q4(raw_is.rp, 0) AS "报告期",
    (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业总收入",
    (((raw_is.data -> '营业收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业收入",
    (((raw_is.data -> '营业总成本(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业总成本",
    (((raw_is.data -> '营业成本(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业成本",
    (((raw_is.data -> '管理费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "管理费用",
    (((raw_is.data -> '销售费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "销售费用",
    (((raw_is.data -> '财务费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "财务费用",
    (((raw_is.data -> '资产减值损失(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "资产减值",
    (((raw_is.data -> '营业税金及附加(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业税金",
    (((raw_is.data -> '投资收益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "投资收益",
    (((raw_is.data -> '公允价值变动收益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "公允价值变动",
    (((raw_is.data -> '营业外收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业外收入",
    (((raw_is.data -> '营业外支出(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "营业外支出",
    (((raw_is.data -> '利润总额(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "利润总额",
    (((raw_is.data -> '所得税费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "所得税",
    (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "净利润",
    (((raw_is.data -> '少数股东损益(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "少数股东损益",
    (((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "归母净利润",
    (((raw_is.data -> '基本每股收益'::text) ->> any_q4(raw_is.rp, 0)))::numeric AS "基本每股收益"
   FROM raw_is
  WITH NO DATA;


--
-- Name: _inst_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE _inst_data (
    id integer NOT NULL,
    code integer,
    update timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    data jsonb
);


--
-- Name: _inst_data_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE _inst_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: _inst_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE _inst_data_id_seq OWNED BY _inst_data.id;


--
-- Name: _pg_yoy_mrq; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _pg_yoy_mrq AS
 SELECT raw_is.code AS "股票代码",
    raw_is.rp AS "报告期",
    (round(((((raw_is.data -> '净利润(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> eofm(raw_is.rp, '-12'::integer)))::numeric), 4) - (1)::numeric) AS "净利同比(mrq)",
    (round(((((raw_is.data -> '净利润(万元)'::text) ->> eofm(raw_is.rp, '-12'::integer)))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> eofm(raw_is.rp, '-24'::integer)))::numeric), 4) - (1)::numeric) AS "净利同比(mrq)1",
    (round(((((raw_is.data -> '净利润(万元)'::text) ->> eofm(raw_is.rp, '-24'::integer)))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> eofm(raw_is.rp, '-36'::integer)))::numeric), 4) - (1)::numeric) AS "净利同比(mrq)2",
    (round(((((raw_is.data -> '净利润(万元)'::text) ->> eofm(raw_is.rp, '-36'::integer)))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> eofm(raw_is.rp, '-48'::integer)))::numeric), 4) - (1)::numeric) AS "净利同比(mrq)3",
    (round(((((raw_is.data -> '净利润(万元)'::text) ->> eofm(raw_is.rp, '-48'::integer)))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> eofm(raw_is.rp, '-60'::integer)))::numeric), 4) - (1)::numeric) AS "净利同比(mrq)4"
   FROM raw_is
  WITH NO DATA;


--
-- Name: _pg_yoy_q4; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _pg_yoy_q4 AS
 SELECT raw_is.code AS "股票代码",
    any_q4(raw_is.rp, 0) AS "最新年报",
    (round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric), 4) - (1)::numeric) AS "净利同比(q4)",
    (round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric), 4) - (1)::numeric) AS "净利同比(q4)1",
    (round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric), 4) - (1)::numeric) AS "净利同比(q4)2",
    (round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric), 4) - (1)::numeric) AS "净利同比(q4)3",
    (round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric // (((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, '-5'::integer)))::numeric), 4) - (1)::numeric) AS "净利同比(q4)4"
   FROM raw_is
  WITH NO DATA;


--
-- Name: _rg_yoy_mrq; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _rg_yoy_mrq AS
 SELECT raw_is.code AS "股票代码",
    raw_is.rp AS "报告期",
    (round(((((raw_is.data -> '营业总收入(万元)'::text) ->> raw_is.rp))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> eofm(raw_is.rp, '-12'::integer)))::numeric), 4) - (1)::numeric) AS "营收同比(mrq)",
    (round(((((raw_is.data -> '营业总收入(万元)'::text) ->> eofm(raw_is.rp, '-12'::integer)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> eofm(raw_is.rp, '-24'::integer)))::numeric), 4) - (1)::numeric) AS "营收同比(mrq)1",
    (round(((((raw_is.data -> '营业总收入(万元)'::text) ->> eofm(raw_is.rp, '-24'::integer)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> eofm(raw_is.rp, '-36'::integer)))::numeric), 4) - (1)::numeric) AS "营收同比(mrq)2",
    (round(((((raw_is.data -> '营业总收入(万元)'::text) ->> eofm(raw_is.rp, '-36'::integer)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> eofm(raw_is.rp, '-48'::integer)))::numeric), 4) - (1)::numeric) AS "营收同比(mrq)3",
    (round(((((raw_is.data -> '营业总收入(万元)'::text) ->> eofm(raw_is.rp, '-48'::integer)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> eofm(raw_is.rp, '-60'::integer)))::numeric), 4) - (1)::numeric) AS "营收同比(mrq)4"
   FROM raw_is
  WITH NO DATA;


--
-- Name: _rg_yoy_q4; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _rg_yoy_q4 AS
 SELECT raw_is.code AS "股票代码",
    any_q4(raw_is.rp, 0) AS "最新年报",
    (round(((((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric), 4) - (1)::numeric) AS "营收同比(q4)",
    (round(((((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric), 4) - (1)::numeric) AS "营收同比(q4)1",
    (round(((((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric), 4) - (1)::numeric) AS "营收同比(q4)2",
    (round(((((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric), 4) - (1)::numeric) AS "营收同比(q4)3",
    (round(((((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric // (((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, '-5'::integer)))::numeric), 4) - (1)::numeric) AS "营收同比(q4)4"
   FROM raw_is
  WITH NO DATA;


--
-- Name: _roa_q4; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _roa_q4 AS
 SELECT raw_bs.code AS "股票代码",
    any_q4(raw_bs.rp, 0) AS "最新年报",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_bs.data -> '资产总计(万元)'::text) ->> any_q4(raw_bs.rp, 0)))::numeric), 4) AS "资产收益率",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric // (((raw_bs.data -> '资产总计(万元)'::text) ->> any_q4(raw_bs.rp, '-1'::integer)))::numeric), 4) AS "资产收益率1",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric // (((raw_bs.data -> '资产总计(万元)'::text) ->> any_q4(raw_bs.rp, '-2'::integer)))::numeric), 4) AS "资产收益率2",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric // (((raw_bs.data -> '资产总计(万元)'::text) ->> any_q4(raw_bs.rp, '-3'::integer)))::numeric), 4) AS "资产收益率3",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric // (((raw_bs.data -> '资产总计(万元)'::text) ->> any_q4(raw_bs.rp, '-4'::integer)))::numeric), 4) AS "资产收益率4"
   FROM raw_bs,
    raw_is
  WHERE (raw_bs.code = raw_is.code)
  WITH NO DATA;


--
-- Name: _roe_mrq; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _roe_mrq AS
 SELECT raw_bs.code AS "股票代码",
    eofm(raw_bs.rp, 0) AS "报告期",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric // (((raw_bs.data -> '归属于母公司股东权益合计(万元)'::text) ->> eofm(raw_bs.rp, 0)))::numeric), 4) AS "净资产收益率",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> eofm(raw_is.rp, '-12'::integer)))::numeric // (((raw_bs.data -> '归属于母公司股东权益合计(万元)'::text) ->> eofm(raw_bs.rp, '-12'::integer)))::numeric), 4) AS "净资产收益率1",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> eofm(raw_is.rp, '-24'::integer)))::numeric // (((raw_bs.data -> '归属于母公司股东权益合计(万元)'::text) ->> eofm(raw_bs.rp, '-24'::integer)))::numeric), 4) AS "净资产收益率2",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> eofm(raw_is.rp, '-36'::integer)))::numeric // (((raw_bs.data -> '归属于母公司股东权益合计(万元)'::text) ->> eofm(raw_bs.rp, '-36'::integer)))::numeric), 4) AS "净资产收益率3",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> eofm(raw_is.rp, '-48'::integer)))::numeric // (((raw_bs.data -> '归属于母公司股东权益合计(万元)'::text) ->> eofm(raw_bs.rp, '-48'::integer)))::numeric), 4) AS "净资产收益率4"
   FROM raw_bs,
    raw_is
  WHERE (raw_bs.code = raw_is.code)
  WITH NO DATA;


--
-- Name: _roe_q4; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _roe_q4 AS
 SELECT raw_bs.code AS "股票代码",
    any_q4(raw_bs.rp, 0) AS "最新年报",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric // (((raw_bs.data -> '归属于母公司股东权益合计(万元)'::text) ->> any_q4(raw_bs.rp, 0)))::numeric), 4) AS "净资产收益率",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, '-1'::integer)))::numeric // (((raw_bs.data -> '归属于母公司股东权益合计(万元)'::text) ->> any_q4(raw_bs.rp, '-1'::integer)))::numeric), 4) AS "净资产收益率1",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, '-2'::integer)))::numeric // (((raw_bs.data -> '归属于母公司股东权益合计(万元)'::text) ->> any_q4(raw_bs.rp, '-2'::integer)))::numeric), 4) AS "净资产收益率2",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, '-3'::integer)))::numeric // (((raw_bs.data -> '归属于母公司股东权益合计(万元)'::text) ->> any_q4(raw_bs.rp, '-3'::integer)))::numeric), 4) AS "净资产收益率3",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, '-4'::integer)))::numeric // (((raw_bs.data -> '归属于母公司股东权益合计(万元)'::text) ->> any_q4(raw_bs.rp, '-4'::integer)))::numeric), 4) AS "净资产收益率4"
   FROM raw_bs,
    raw_is
  WHERE (raw_bs.code = raw_is.code)
  WITH NO DATA;


--
-- Name: _s_mrqa; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _s_mrqa AS
 SELECT raw_bs.code AS "股票代码",
    eofm(raw_bs.rp, 0) AS "最新季报",
    round(((((raw_bs.data -> '流动资产合计(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "流动资产",
    round(((((raw_bs.data -> '非流动资产合计(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "非流动资产",
    (round(((((raw_bs.data -> '流动资产合计(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) - round(((((raw_bs.data -> '流动负债合计(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2)) AS "营运资本",
    round(((((raw_bs.data -> '商誉(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "商誉",
    round(((((raw_bs.data -> '资产总计(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "总资产",
    ((round(((((raw_bs.data -> '固定资产净值(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) + round(((((raw_bs.data -> '无形资产(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2)) + round(((((raw_bs.data -> '长期待摊费用(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2)) AS "PPE余额",
    (((round(((((raw_bs.data -> '短期借款(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) + round(((((raw_bs.data -> '长期借款(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2)) + round(((((raw_bs.data -> '一年内到期的非流动负债(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2)) + round(((((raw_bs.data -> '其他流动负债(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2)) AS "有息债务",
    round(((((raw_bs.data -> '负债合计(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "总负债",
    round(((((raw_bs.data -> '归属于母公司股东权益合计(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "归母净资产",
    round(((((raw_bs.data -> '所有者权益(或股东权益)合计(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "净资产",
    round(((((raw_is.data -> '营业总收入(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "营业总收入",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "归母净利润",
    round(((((raw_is.data -> '净利润(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "净利润",
    round(((((raw_cf.data -> '经营活动产生的现金流量净额(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "经营",
    round(((((raw_cf.data -> '投资活动产生的现金流量净额(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "投资",
    round(((((raw_cf.data -> '筹资活动产生的现金流量净额(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "筹资",
    round(((((raw_cf.data -> '现金及现金等价物的净增加额(万元)'::text) ->> eofm(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "净现金流"
   FROM ((raw_is
     JOIN raw_bs ON ((raw_is.code = raw_bs.code)))
     JOIN raw_cf ON ((raw_bs.code = raw_cf.code)))
  WITH NO DATA;


--
-- Name: _s_q4a; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW _s_q4a AS
 SELECT raw_bs.code AS "股票代码",
    any_q4(raw_bs.rp, 0) AS "最新年报",
    round(((((raw_bs.data -> '流动资产合计(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "流动资产",
    round(((((raw_bs.data -> '非流动资产合计(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "非流动资产",
    (round(((((raw_bs.data -> '流动资产合计(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) - round(((((raw_bs.data -> '流动负债合计(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2)) AS "营运资本",
    round(((((raw_bs.data -> '资产总计(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "总资产",
    round(((((raw_bs.data -> '商誉(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "商誉",
    ((round(((((raw_bs.data -> '固定资产净值(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) + round(((((raw_bs.data -> '无形资产(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2)) + round(((((raw_bs.data -> '长期待摊费用(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2)) AS "PPE余额",
    (((round(((((raw_bs.data -> '短期借款(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) + round(((((raw_bs.data -> '长期借款(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2)) + round(((((raw_bs.data -> '一年内到期的非流动负债(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2)) + round(((((raw_bs.data -> '其他流动负债(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2)) AS "有息债务",
    round(((((raw_bs.data -> '负债合计(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "总负债",
    round(((((raw_bs.data -> '归属于母公司股东权益合计(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "归母净资产",
    round(((((raw_bs.data -> '所有者权益(或股东权益)合计(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "净资产",
    round(((((raw_is.data -> '营业总收入(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "营业总收入",
    round(((((raw_is.data -> '归属于母公司所有者的净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "归母净利润",
    round(((((raw_is.data -> '净利润(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "净利润",
    round(((((raw_cf.data -> '经营活动产生的现金流量净额(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "经营",
    round(((((raw_cf.data -> '投资活动产生的现金流量净额(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "投资",
    round(((((raw_cf.data -> '筹资活动产生的现金流量净额(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "筹资",
    round(((((raw_cf.data -> '现金及现金等价物的净增加额(万元)'::text) ->> any_q4(raw_is.rp, 0)))::numeric / (10000)::numeric), 2) AS "净现金流"
   FROM ((raw_is
     JOIN raw_bs ON ((raw_is.code = raw_bs.code)))
     JOIN raw_cf ON ((raw_bs.code = raw_cf.code)))
  WITH NO DATA;


--
-- Name: _tbl_va; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE _tbl_va (
    code bigint,
    name text,
    price double precision,
    pe_ttm double precision,
    mktcap double precision,
    pb double precision,
    pctchg double precision,
    turnover double precision,
    inserted timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: TABLE _tbl_va; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE _tbl_va IS '市场数据';


--
-- Name: tsu_basics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE tsu_basics (
    code integer,
    name text,
    area text,
    industry text,
    outstanding double precision,
    totals double precision,
    holders double precision
);


--
-- Name: bod; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW bod AS
 SELECT a.code,
    a.name,
    a.area,
    a.industry AS idst,
    a.totals AS total_shares,
    a.outstanding AS out_shares,
    round((b.shares / (100000000)::numeric), 4) AS mgmt_shares,
    round((b.salaries / (100000000)::numeric), 4) AS salaries
   FROM (tsu_basics a
     LEFT JOIN _bod_summ b ON ((a.code = b.code)));


--
-- Name: cashflows_q4; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW cashflows_q4 AS
 SELECT a.code,
    a.name,
    b."最新年报" AS rp,
    a.industry AS idst,
    a.area,
    round((b."三年净利润" / (10000)::numeric), 2) AS ni3,
    round((b."三年经营现金流" / (10000)::numeric), 2) AS c3,
    round((b."现金流减利润" / (10000)::numeric), 2) AS nicf,
    round((b."现金流减利润1" / (10000)::numeric), 2) AS nicf1,
    round((b."现金流减利润2" / (10000)::numeric), 2) AS nicf2,
    round((b."现金流减利润3" / (10000)::numeric), 2) AS nicf3,
    round((b."现金流减利润4" / (10000)::numeric), 2) AS nicf4
   FROM tsu_basics a,
    _cashflows_q4 b
  WHERE (a.code = b."股票代码");


--
-- Name: cog_q4; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW cog_q4 AS
 SELECT a."股票代码" AS code,
    b.name,
    a."最新年报" AS rp,
    b.industry AS idst,
    b.area,
    round((a."管理费用" // a."净利润"), 2) AS mgmt,
    round((a."少数股东损益" // a."净利润"), 2) AS os2p,
    round((a."其他应收款" // a."净利润"), 2) AS o_rcpt,
    round((a."其他应付款" // a."净利润"), 2) AS o_pymt,
    round((a."当前股利" // a."净利润"), 2) AS dp,
    round((a."三年累积股利" // a."三年净利"), 2) AS dp3,
    round((a."少数股东损益" // a."少数股东权益"), 2) AS osr,
    round(((a."股权融资" - a."三年累积股利") / (10000)::numeric), 2) AS fdp,
    round(a."股本变动倍数", 2) AS s_x
   FROM _cog_q4a a,
    tsu_basics b
  WHERE (a."股票代码" = b.code);


--
-- Name: cons_data; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW cons_data AS
 SELECT _cons_data.code,
    round((((_cons_data.data -> to_char((CURRENT_DATE - '1 year'::interval), 'yyyy'::text)) ->> '3'::text))::numeric, 2) AS pg,
    round((((_cons_data.data -> (to_char((CURRENT_DATE)::timestamp with time zone, 'yyyy'::text) || '预测'::text)) ->> '3'::text))::numeric, 2) AS e_pg0,
    round((((_cons_data.data -> (to_char((CURRENT_DATE + '1 year'::interval), 'yyyy'::text) || '预测'::text)) ->> '3'::text))::numeric, 2) AS e_pg1,
    round((((_cons_data.data -> (to_char((CURRENT_DATE + '2 years'::interval), 'yyyy'::text) || '预测'::text)) ->> '3'::text))::numeric, 2) AS e_pg2
   FROM _cons_data;


--
-- Name: cons_data_pe; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW cons_data_pe AS
 SELECT _cons_data.code,
    round((((_cons_data.data -> to_char((CURRENT_DATE - '1 year'::interval), 'yyyy'::text)) ->> '5'::text))::numeric, 2) AS pe,
    round((((_cons_data.data -> (to_char((CURRENT_DATE)::timestamp with time zone, 'yyyy'::text) || '预测'::text)) ->> '5'::text))::numeric, 2) AS e_pe0,
    round((((_cons_data.data -> (to_char((CURRENT_DATE + '1 year'::interval), 'yyyy'::text) || '预测'::text)) ->> '5'::text))::numeric, 2) AS e_pe1,
    round((((_cons_data.data -> (to_char((CURRENT_DATE + '2 years'::interval), 'yyyy'::text) || '预测'::text)) ->> '5'::text))::numeric, 2) AS e_pe2
   FROM _cons_data;


--
-- Name: cost_mrqa; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW cost_mrqa AS
 SELECT a.code,
    a.name,
    a.area,
    a.industry AS idst,
    b."报告期" AS rp,
    ((1)::numeric - b."营业成本") AS gpm,
    b."管理费用" AS aer,
    b."销售费用" AS ser,
    b."财务费用" AS fer,
    ((b."管理费用" + b."销售费用") + b."财务费用") AS sga,
    ((((1)::numeric - b."营业成本") - b."管理费用") - b."销售费用") AS ccr,
    b."资产减值" AS ail,
    ((b."营业外收入" - b."营业外支出") + b."投资收益") AS other,
    b."净利润" AS npm,
    b."少数股东损益" AS ncl
   FROM tsu_basics a,
    _cost_mrq b
  WHERE (a.code = b."股票代码");


--
-- Name: cost_q4a; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW cost_q4a AS
 SELECT a.code,
    a.name,
    a.area,
    a.industry AS idst,
    b."报告期" AS rp,
    ((1)::numeric - b."营业成本") AS gpm,
    b."管理费用" AS aer,
    b."销售费用" AS ser,
    b."财务费用" AS fer,
    ((b."管理费用" + b."销售费用") + b."财务费用") AS sga,
    ((((1)::numeric - b."营业成本") - b."管理费用") - b."销售费用") AS ccr,
    b."资产减值" AS ail,
    ((b."营业外收入" - b."营业外支出") + b."投资收益") AS other,
    b."净利润" AS npm,
    b."少数股东损益" AS ncl
   FROM tsu_basics a,
    _cost_q4a b
  WHERE (a.code = b."股票代码");


--
-- Name: f_data_error; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW f_data_error AS
 SELECT _data_stats.code,
    _data_stats.bsrp,
    _data_stats.isrp,
    _data_stats.cfrp
   FROM _data_stats
  WHERE ((_data_stats.bsrp <> _data_stats.cfrp) OR (_data_stats.bsrp <> _data_stats.isrp) OR (_data_stats.isrp <> _data_stats.cfrp));


--
-- Name: f_data_stat; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW f_data_stat AS
 SELECT a.rp,
    a.bsrp,
    b.isrp,
    c.cfrp
   FROM ((( SELECT raw_bs.rp,
            count(*) AS bsrp
           FROM raw_bs
          GROUP BY raw_bs.rp) a
     JOIN ( SELECT raw_is.rp,
            count(*) AS isrp
           FROM raw_is
          GROUP BY raw_is.rp) b ON ((a.rp = b.rp)))
     JOIN ( SELECT raw_cf.rp,
            count(*) AS cfrp
           FROM raw_cf
          GROUP BY raw_cf.rp) c ON ((b.rp = c.rp)));


--
-- Name: income_mrqa; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW income_mrqa AS
 SELECT b.code,
    b.name,
    b.industry AS idst,
    b.area,
    a."报告期" AS rp,
    a."营业总收入" AS is01,
    a."营业收入" AS is02,
    a."营业总成本" AS is03,
    a."营业成本" AS is04,
    a."管理费用" AS is05,
    a."财务费用" AS is06,
    a."销售费用" AS is07,
    a."资产减值" AS is08,
    a."营业税金" AS is09,
    a."投资收益" AS is10,
    a."公允价值变动" AS is11,
    a."营业外收入" AS is12,
    a."营业外支出" AS is13,
    a."利润总额" AS is14,
    a."所得税" AS is15,
    a."净利润" AS is16,
    a."少数股东损益" AS is17,
    a."归母净利润" AS is18,
    a."基本每股收益" AS is19
   FROM (_income_mrqa a
     JOIN tsu_basics b ON ((a."股票代码" = b.code)));


--
-- Name: income_q4a; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW income_q4a AS
 SELECT b.code,
    b.name,
    b.industry AS idst,
    b.area,
    a."报告期" AS rp,
    a."营业总收入" AS is01,
    a."营业收入" AS is02,
    a."营业总成本" AS is03,
    a."营业成本" AS is04,
    a."管理费用" AS is05,
    a."财务费用" AS is06,
    a."销售费用" AS is07,
    a."资产减值" AS is08,
    a."营业税金" AS is09,
    a."投资收益" AS is10,
    a."公允价值变动" AS is11,
    a."营业外收入" AS is12,
    a."营业外支出" AS is13,
    a."利润总额" AS is14,
    a."所得税" AS is15,
    a."净利润" AS is16,
    a."少数股东损益" AS is17,
    a."归母净利润" AS is18,
    a."基本每股收益" AS is19
   FROM (_income_q4a a
     JOIN tsu_basics b ON ((a."股票代码" = b.code)));


--
-- Name: inst_data; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW inst_data AS
 SELECT _inst_data.code,
    (((_inst_data.data -> '家数'::text) ->> '1'::text))::numeric AS inst2,
    (((_inst_data.data -> '家数'::text) ->> '2'::text))::numeric AS inst3,
    (((_inst_data.data -> '评级系数'::text) ->> '1'::text))::numeric AS ef2,
    (((_inst_data.data -> '评级系数'::text) ->> '2'::text))::numeric AS ef3
   FROM _inst_data;


--
-- Name: inst; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW inst AS
 SELECT a.code,
    a.name,
    a.industry AS idst,
    a.area,
    b.pg,
    b.e_pg0,
    b.e_pg1,
    b.e_pg2,
    c.inst2,
    c.inst3,
    c.ef2,
    c.ef3
   FROM ((tsu_basics a
     JOIN cons_data b ON ((a.code = b.code)))
     JOIN inst_data c ON ((b.code = c.code)));


--
-- Name: inst2; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW inst2 AS
 SELECT a.code,
    a.name,
    a.industry AS idst,
    a.area,
    b.pe,
    b.e_pe0,
    b.e_pe1,
    b.e_pe2,
    c.inst2,
    c.inst3,
    c.ef2,
    c.ef3
   FROM ((tsu_basics a
     JOIN cons_data_pe b ON ((a.code = b.code)))
     JOIN inst_data c ON ((b.code = c.code)));


--
-- Name: pg_yoy_q4; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW pg_yoy_q4 AS
 SELECT _pg_yoy_q4."股票代码" AS code,
    _pg_yoy_q4."最新年报" AS rp,
    tsu_basics.name,
    tsu_basics.industry AS idst,
    tsu_basics.area,
    _pg_yoy_q4."净利同比(q4)" AS pg_q4,
    _pg_yoy_q4."净利同比(q4)1" AS pg_q4_1,
    _pg_yoy_q4."净利同比(q4)2" AS pg_q4_2,
    _pg_yoy_q4."净利同比(q4)3" AS pg_q4_3,
    _pg_yoy_q4."净利同比(q4)4" AS pg_q4_4
   FROM (_pg_yoy_q4
     JOIN tsu_basics ON ((_pg_yoy_q4."股票代码" = tsu_basics.code)));


--
-- Name: raw_bs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE raw_bs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: raw_bs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE raw_bs_id_seq OWNED BY raw_bs.id;


--
-- Name: raw_cf_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE raw_cf_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: raw_cf_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE raw_cf_id_seq OWNED BY raw_cf.id;


--
-- Name: raw_is_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE raw_is_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: raw_is_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE raw_is_id_seq OWNED BY raw_is.id;


--
-- Name: rg_yoy_q4; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW rg_yoy_q4 AS
 SELECT _rg_yoy_q4."股票代码" AS code,
    _rg_yoy_q4."最新年报" AS rp,
    tsu_basics.name,
    tsu_basics.industry AS idst,
    tsu_basics.area,
    _rg_yoy_q4."营收同比(q4)" AS rg_q4,
    _rg_yoy_q4."营收同比(q4)1" AS rg_q4_1,
    _rg_yoy_q4."营收同比(q4)2" AS rg_q4_2,
    _rg_yoy_q4."营收同比(q4)3" AS rg_q4_3,
    _rg_yoy_q4."营收同比(q4)4" AS rg_q4_4
   FROM (_rg_yoy_q4
     JOIN tsu_basics ON ((_rg_yoy_q4."股票代码" = tsu_basics.code)));


--
-- Name: roe_mrq; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW roe_mrq AS
 SELECT a.code,
    a.name,
    a.industry AS idst,
    a.area,
    b."报告期" AS rp,
    b."净资产收益率" AS roe,
    b."净资产收益率1" AS roe1,
    b."净资产收益率2" AS roe2,
    b."净资产收益率3" AS roe3,
    b."净资产收益率4" AS roe4
   FROM _roe_mrq b,
    tsu_basics a
  WHERE (a.code = b."股票代码");


--
-- Name: roe_q4; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW roe_q4 AS
 SELECT a.code,
    a.name,
    a.industry AS idst,
    a.area,
    b."最新年报" AS rp,
    b."净资产收益率" AS roe,
    b."净资产收益率1" AS roe1,
    b."净资产收益率2" AS roe2,
    b."净资产收益率3" AS roe3,
    b."净资产收益率4" AS roe4
   FROM _roe_q4 b,
    tsu_basics a
  WHERE (a.code = b."股票代码");


--
-- Name: s_mrqa; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW s_mrqa AS
 SELECT _s_mrqa."股票代码" AS code,
    tsu_basics.name,
    tsu_basics.industry AS idst,
    tsu_basics.area,
    _s_mrqa."最新季报" AS rp,
    _s_mrqa."流动资产" AS ca,
    _s_mrqa."非流动资产" AS nca,
    _s_mrqa."营运资本" AS wca,
    _s_mrqa."商誉" AS gw,
    _s_mrqa."总资产" AS tca,
    _s_mrqa."PPE余额" AS ppe,
    _s_mrqa."有息债务" AS debts,
    _s_mrqa."总负债" AS tlbt,
    _s_mrqa."归母净资产" AS nae,
    _s_mrqa."净资产" AS na,
    _s_mrqa."营业总收入" AS rve,
    _s_mrqa."归母净利润" AS npe,
    _s_mrqa."净利润" AS np,
    _s_mrqa."经营" AS ocf,
    _s_mrqa."投资" AS icf,
    _s_mrqa."筹资" AS ficf,
    _s_mrqa."净现金流" AS ncf
   FROM (_s_mrqa
     JOIN tsu_basics ON ((_s_mrqa."股票代码" = tsu_basics.code)));


--
-- Name: s_q4a; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW s_q4a AS
 SELECT _s_q4a."股票代码" AS code,
    tsu_basics.name,
    tsu_basics.industry AS idst,
    tsu_basics.area,
    _s_q4a."最新年报" AS rp,
    _s_q4a."流动资产" AS ca,
    _s_q4a."非流动资产" AS nca,
    _s_q4a."营运资本" AS wca,
    _s_q4a."总资产" AS tca,
    _s_q4a."商誉" AS gw,
    _s_q4a."PPE余额" AS ppe,
    _s_q4a."有息债务" AS debts,
    _s_q4a."总负债" AS tlbt,
    _s_q4a."归母净资产" AS nae,
    _s_q4a."净资产" AS na,
    _s_q4a."营业总收入" AS rve,
    _s_q4a."归母净利润" AS npe,
    _s_q4a."净利润" AS np,
    _s_q4a."经营" AS ocf,
    _s_q4a."投资" AS icf,
    _s_q4a."筹资" AS ficf,
    _s_q4a."净现金流" AS ncf
   FROM (_s_q4a
     JOIN tsu_basics ON ((_s_q4a."股票代码" = tsu_basics.code)));


--
-- Name: va_mrqa; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW va_mrqa AS
 SELECT _tbl_va.code,
    _tbl_va.name,
    _growth_report_mrq."报告期" AS rp,
    tsu_basics.industry AS idst,
    tsu_basics.area,
    (_tbl_va.price)::numeric AS close,
    (_tbl_va.pe_ttm)::numeric AS pe_ttm,
    (_tbl_va.pb)::numeric AS pb,
    round(((_tbl_va.pb)::numeric // (_tbl_va.pe_ttm)::numeric), 4) AS roe_ttm,
    (_tbl_va.mktcap)::numeric AS mktcap,
    (_tbl_va.pctchg)::numeric AS pctchg,
    (_tbl_va.turnover)::numeric AS turnover,
    _growth_report_mrq."营收同比" AS rg,
    _growth_report_mrq."利润同比" AS pg,
    _growth_report_mrq."营收复合" AS crg,
    _growth_report_mrq."利润复合" AS cpg,
    round((((_tbl_va.pe_ttm)::numeric // (100)::numeric) // _growth_report_mrq."利润同比"), 2) AS peg
   FROM _tbl_va,
    tsu_basics,
    _growth_report_mrq
  WHERE ((_tbl_va.inserted = ( SELECT max(_tbl_va_1.inserted) AS max
           FROM _tbl_va _tbl_va_1)) AND (_tbl_va.code = tsu_basics.code) AND (_tbl_va.code = _growth_report_mrq."股票代码"));


--
-- Name: tdx_va_mrq; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW tdx_va_mrq AS
 SELECT t.idst AS idst_name,
    count(*) AS count,
    percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((t.pe_ttm)::double precision)) FILTER (WHERE ((t.pe_ttm)::double precision > (0)::double precision)) AS pe50,
    percentile_cont((0.25)::double precision) WITHIN GROUP (ORDER BY ((t.pe_ttm)::double precision)) FILTER (WHERE ((t.pe_ttm)::double precision > (0)::double precision)) AS pe25,
    percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((t.pb)::double precision)) FILTER (WHERE ((t.pb)::double precision > (0)::double precision)) AS pb50,
    percentile_cont((0.25)::double precision) WITHIN GROUP (ORDER BY ((t.pb)::double precision)) FILTER (WHERE ((t.pb)::double precision > (0)::double precision)) AS pb25,
    percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((t.roe_ttm)::double precision)) AS roe50,
    percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((t.rg)::double precision)) AS rg50,
    percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((t.pg)::double precision)) AS pg50,
    percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((t.crg)::double precision)) AS crg50,
    percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((t.cpg)::double precision)) AS cpg50,
    percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((t.pctchg)::double precision)) AS c50,
    percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((t.turnover)::double precision)) AS to50
   FROM ( SELECT va.code,
            va.name,
            va.pe_ttm,
            va.pb,
            va.mktcap,
            va.close,
            va.roe_ttm,
            va.pctchg,
            va.turnover,
            va.idst,
            va.rg,
            va.pg,
            va.crg,
            va.cpg
           FROM va_mrqa va) t
  GROUP BY t.idst
  ORDER BY (percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((t.pe_ttm)::double precision)) FILTER (WHERE ((t.pe_ttm)::double precision > (0)::double precision)));


--
-- Name: va_q4a; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW va_q4a AS
 SELECT _tbl_va.code,
    _tbl_va.name,
    _growth_report_q4."最新年报" AS rp,
    tsu_basics.industry AS idst,
    tsu_basics.area,
    (_tbl_va.price)::numeric AS close,
    (_tbl_va.pe_ttm)::numeric AS pe_ttm,
    (_tbl_va.pb)::numeric AS pb,
    round(((_tbl_va.pb)::numeric // (_tbl_va.pe_ttm)::numeric), 4) AS roe_ttm,
    (_tbl_va.mktcap)::numeric AS mktcap,
    (_tbl_va.pctchg)::numeric AS pctchg,
    (_tbl_va.turnover)::numeric AS turnover,
    _growth_report_q4."营收同比" AS rg,
    _growth_report_q4."利润同比" AS pg,
    _growth_report_q4."营收复合" AS crg,
    _growth_report_q4."利润复合" AS cpg,
    round((((_tbl_va.pe_ttm)::numeric // (100)::numeric) // _growth_report_q4."利润同比"), 2) AS peg
   FROM _tbl_va,
    tsu_basics,
    _growth_report_q4
  WHERE ((_tbl_va.inserted = ( SELECT max(_tbl_va_1.inserted) AS max
           FROM _tbl_va _tbl_va_1)) AND (_tbl_va.code = tsu_basics.code) AND (_tbl_va.code = _growth_report_q4."股票代码"));


--
-- Name: _cons_data id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY _cons_data ALTER COLUMN id SET DEFAULT nextval('_cons_data_id_seq'::regclass);


--
-- Name: _inst_data id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY _inst_data ALTER COLUMN id SET DEFAULT nextval('_inst_data_id_seq'::regclass);


--
-- Name: raw_bs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY raw_bs ALTER COLUMN id SET DEFAULT nextval('raw_bs_id_seq'::regclass);


--
-- Name: raw_cf id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY raw_cf ALTER COLUMN id SET DEFAULT nextval('raw_cf_id_seq'::regclass);


--
-- Name: raw_is id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY raw_is ALTER COLUMN id SET DEFAULT nextval('raw_is_id_seq'::regclass);


--
-- Name: _cons_data _cons_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY _cons_data
    ADD CONSTRAINT _cons_data_pkey PRIMARY KEY (id);


--
-- Name: _inst_data _inst_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY _inst_data
    ADD CONSTRAINT _inst_data_pkey PRIMARY KEY (id);


--
-- Name: raw_bs balance_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY raw_bs
    ADD CONSTRAINT balance_data_pkey PRIMARY KEY (id);


--
-- Name: raw_cf cash_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY raw_cf
    ADD CONSTRAINT cash_data_pkey PRIMARY KEY (id);


--
-- Name: raw_is income_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY raw_is
    ADD CONSTRAINT income_data_pkey PRIMARY KEY (id);


--
-- Name: ix_bs_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_bs_data ON raw_bs USING gin (data);


--
-- Name: ix_cf_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cf_data ON raw_cf USING gin (data);


--
-- Name: ix_csrc_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_csrc_code ON _csrc USING btree (code);


--
-- Name: ix_is_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_is_data ON raw_is USING gin (data);


--
-- Name: ix_raw_bs_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_raw_bs_code ON raw_bs USING btree (code);


--
-- Name: ix_raw_cf_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_raw_cf_code ON raw_cf USING btree (code);


--
-- Name: ix_raw_is_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_raw_is_code ON raw_is USING btree (code);


--
-- Name: ix_tbl_va_istd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_tbl_va_istd ON _tbl_va USING btree (inserted);


--
-- Name: ix_tsu_basics_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_tsu_basics_code ON tsu_basics USING btree (code);


--
-- Name: tsu_basics; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE tsu_basics TO ovwx;


--
-- Name: bod; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE bod TO ovwx;


--
-- Name: cashflows_q4; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE cashflows_q4 TO ovwx;


--
-- Name: cog_q4; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE cog_q4 TO ovwx;


--
-- Name: cost_mrqa; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE cost_mrqa TO ovwx;


--
-- Name: cost_q4a; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE cost_q4a TO ovwx;


--
-- Name: income_mrqa; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE income_mrqa TO ovwx;


--
-- Name: income_q4a; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE income_q4a TO ovwx;


--
-- Name: inst; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE inst TO ovwx;


--
-- Name: inst2; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE inst2 TO ovwx;


--
-- Name: pg_yoy_q4; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE pg_yoy_q4 TO ovwx;


--
-- Name: rg_yoy_q4; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE rg_yoy_q4 TO ovwx;


--
-- Name: roe_mrq; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE roe_mrq TO ovwx;


--
-- Name: roe_q4; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE roe_q4 TO ovwx;


--
-- Name: s_mrqa; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE s_mrqa TO ovwx;


--
-- Name: s_q4a; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE s_q4a TO ovwx;


--
-- Name: va_mrqa; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE va_mrqa TO ovwx;


--
-- Name: tdx_va_mrq; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE tdx_va_mrq TO ovwx;


--
-- Name: va_q4a; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE va_q4a TO ovwx;


--
-- PostgreSQL database dump complete
--

