-- abc_xyz анализ
with amount as ( -- промежуточная таблица для расчета abc
    select
        dr_ndrugs,
        sum(dr_kol) as sum_amt,
        sum(dr_kol * dr_croz - dr_sdisc) as sum_profit,
        sum((dr_croz - dr_czak) * dr_kol  - dr_sdisc) as sum_revenue
    from sales
    group by dr_ndrugs
), abc as ( -- окончательная широкая таблица abc
    select
        dr_ndrugs,
        case 
            when sum(sum_amt) over(order by sum_amt desc)/sum(sum_amt) over() <= 0.8 then 'A'
            when sum(sum_amt) over(order by sum_amt desc)/sum(sum_amt) over() <= 0.95 then 'B'
            else 'C'
            end amount_abc,
        case 
            when sum(sum_profit) over(order by sum_profit desc)/sum(sum_profit) over() <= 0.8 then 'A'
            when sum(sum_profit) over(order by sum_profit desc)/sum(sum_profit) over() <= 0.95 then 'B'
            else 'C'
            end profit_abc,
        case 
            when sum(sum_revenue) over(order by sum_revenue desc)/sum(sum_revenue) over() <= 0.8 then 'A'
            when sum(sum_revenue) over(order by sum_revenue desc)/sum(sum_revenue) over() <= 0.95 then 'B'
            else 'C'
            end revenue_abc
    from amount
), summ as ( -- промежуточная таблица для xyz с расчетом количества продаж по неделям
    select
        dr_ndrugs,
        extract (week from dr_dat) as period,
        sum(dr_kol) as sum_kol
    from sales
    group by dr_ndrugs, period
), percent_dev as ( -- промежуточная таблица для xyz с расчетом стандартного отклонения по недельным продажам и количества недель, в которых были продажи
    select
        dr_ndrugs,
        period,
        sum_kol,
        count(period) over (partition by dr_ndrugs) as kol_week,
        stddev(sum_kol) over (partition by dr_ndrugs) / avg(sum_kol) over (partition by dr_ndrugs)*100 as percent_dev
    from summ
), percent_dev_2 as ( -- промежуточная таблица для xyz с расчетом стандартного отклонения по недельным продажам и исключением позиций, которые продавались меньше четырех недель
    select distinct
        dr_ndrugs,
        kol_week,
        percent_dev
    from percent_dev
    where kol_week >= 4
), xyz as ( -- окончательная широкая таблица xyz
    select
        dr_ndrugs,
        case
            when percent_dev <= 10 then 'X'
            when percent_dev <= 25 then 'Y'
            else 'Z' end xyz_sales
    from percent_dev_2
)
select -- объединение abc и xyz анализов
    abc.dr_ndrugs as наименование_товара,
    abc.amount_abc as abc_количество,
    abc.profit_abc as abc_прибыль,
    abc.revenue_abc as abc_доход,
    xyz.xyz_sales as xyz
from abc
left join xyz
on abc.dr_ndrugs = xyz.dr_ndrugs

--сочетаемость товаров
with tmp as (
    select distinct -- исключаем повторы продуктов в чеке
        dr_dat || ' ' ||  dr_apt || ' ' || dr_nchk as cheque, -- формируем уникальный чек
        dr_cdrugs,
        dr_ndrugs
    from sales
), tmp2 as ( -- запрос для формирования пар продуктов
    select
        s.dr_ndrugs as product1,
        s2.dr_ndrugs as product2,
        s.cheque
    from tmp s
    join tmp s2
    on s.dr_ndrugs < s2.dr_ndrugs -- исключаем повторы пар и пары "сам с собой"
    and s.cheque = s2.cheque
)
select
    product1 as "товар_1",
    product2 as "товар_2",
    count(distinct cheque) as "кол-во сочетаний" 
from tmp2
group by product1, product2
order by "кол-во сочетаний" desc