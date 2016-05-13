connect to c3421m;


-- which books have 'like' or Like in the title
select B.title, B.year, B.cat as category
from yrb_book B
where B.title like '%like%' or B.title like '%Like%'
order by B.title, B.year, B.cat;


-- For each club, what are 
--	the total sales, 
--	the number of distinct book titles (title + year) bought via that club, and 
--	the number of customers who belong to that club? 
with title_count (club, titles) as (
		select P1.club, count(*) as title
		from (select distinct P.club, P.title, P.year 
			  from yrb_purchase P) as P1
		group by P1.club
	),
	 sales_count (club, sales) as (
		select P2.club, sum(P2.sale) as sales
		from (select P.club, (O.price * P.qnty) as sale
			  from yrb_purchase P, yrb_offer O
			  where P.club = O.club and P.title = O.title and P.year = O.year) as P2
		group by P2.club
	), 
	 member_count (club, membership) as (
		select M.club, count(*) as membership
		from yrb_member M
		group by M.club
	)
select TC.club, SC.sales, TC.titles, MC.membership
from title_count TC, sales_count SC, member_count MC
where TC.club = SC.club and TC.club = MC.club
order by SC.sales desc, TC.club desc;

-- fei mySql 20160416
SELECT TC.club 
       ,SC.sales 
       ,TC.title 
       ,MC.membership 
FROM   (SELECT P1.club 
               ,Count(*) AS title 
        FROM   (SELECT DISTINCT P.club 
                                ,P.title 
                                ,P.year 
                FROM   yrb_purchase P) AS P1 
        GROUP  BY P1.club) TC 
       ,(SELECT P2.club 
                ,Sum(P2.sale) AS sales 
         FROM   (SELECT P.club 
                        ,( O.price * P.qnty ) AS sale 
                 FROM   yrb_purchase P 
                        ,yrb_offer O 
                 WHERE  P.club = O.club 
                        AND P.title = O.title 
                        AND P.year = O.year) AS P2 
         GROUP  BY P2.club) SC 
       ,(SELECT M.club 
                ,Count(*) AS membership 
         FROM   yrb_member M 
         GROUP  BY M.club) MC 
WHERE  TC.club = SC.club 
       AND TC.club = MC.club 
ORDER  BY SC.sales DESC 
          ,TC.club DESC; 


-- Which cities had no one in that city purchase any books in French? 
with nofrench (city) as (
		select distinct C.city
		from yrb_purchase P, yrb_customer C
		where P.cid = C.cid
		except
		select distinct C.city
		from yrb_purchase P, yrb_customer C, yrb_book B
		where P.cid = C.cid and P.title = B.title and P.year = B.year and B.language = 'French'
	)
select NC.city 
from nofrench NC
order by NC.city;

-- fei mySql 20160416
select NC.city 
from (
		select distinct C.city
		from yrb_purchase P, yrb_customer C
		where P.cid = C.cid AND C.city
		NOT in
		(select distinct C.city
		from yrb_purchase P, yrb_customer C, yrb_book B
		where P.cid = C.cid and P.title = B.title and P.year = B.year and B.language = 'French')
	) NC
order by NC.city;

-- To how many university clubs does each customer belong?
-- If a customer belongs to none, list zero for that customer
with nonzero (cid, #uniclubs) as (
		select distinct M.cid, count(*) as #uniclubs
		from yrb_member M, yrb_club C
		where M.club = C.club and (C.desc like '%University%' or C.desc like '%university%')
		group by M.cid
	)
select Temp.name, Temp.city, Temp.#uniclubs
from   (select C.name, C.city, (0) as #uniclubs
		from yrb_customer C
		where C.cid not in (select NZ.cid from nonzero NZ)
		union
		select C.name, C.city, NZ.#uniclubs
		from yrb_customer C, nonzero NZ
		where C.cid = NZ.cid) as Temp
order by Temp.name, Temp.city;

-- fei mySql 20160416
SELECT ym.name, ym.city, ifnull(U.qtyClub, 0)
FROM yrb_customer ym LEFT JOIN
	(
	select M.cid AS ID, count(c.club) AS qtyClub
	from yrb_member M, yrb_club C
	WHERE M.club = C.club AND C.description LIKE '%university%'
	GROUP BY M.cid
	) U
ON ym.cid = U.id
ORDER BY ym.name


-- Which customers have bought more than one copy of the same book over time?  
with repeat (cid, title, year, total) as (
		select distinct P.cid, P.title, P.year, sum(P.qnty) as total
		from yrb_purchase P
		group by P.cid, P.title, P.year
		having sum(P.qnty) > 1
	)
select C.name, R.title, R.year, R.total
from yrb_customer C, repeat R
where C.cid = R.cid
order by C.name, R.title, R.year; 

-- fei mySql 20160416
select C.name, R.title, R.year, R.total
from yrb_customer C right join
	(
		select P.cid, P.title, P.year, sum(P.qnty) as total
		from yrb_purchase P
		group by P.cid, P.title, P.year
		having sum(P.qnty) > 1
	) R
on C.cid = R.cid
order by C.name, R.title, R.year;

-- Which customers have bought all the books offerred within some category / language group, 
-- given that category / language group contains more than one book title?
with allbooks (cat, language) as (
		select distinct B.cat, B.language 
		from yrb_book B
		group by B.cat, B.language
		having count(*) > 1
		)
select C.name, AB.cat as category, AB.language
from yrb_customer C, allbooks as AB
where (	not exists (select distinct P.title, P.year
					from yrb_purchase P, yrb_book BB
					where 	P.year = BB.year and P.title = BB.title and
							AB.cat = BB.cat and AB.language = BB.language
					except
					select distinct P.title, P.year
					from yrb_purchase P
					where P.cid = C.cid))
order by C.name, AB.cat, AB.language;




-- What is the bill for each order?
-- All the books a customer orders at the same time (when) are considered to be part of the same "order".
with orders (cid, when, bill) as (
		select P.cid, P.when, sum(O.price * P.qnty) as bill
		from yrb_purchase P, yrb_offer O
		where P.club = O.club and P.title = O.title and P.year = O.year
		group by P.cid, P.when
	)
select C.name, C.city, 
	   cast (O.when as date) as day, cast (O.when as time) as time, 
	   cast (O.bill as decimal(5,2)) as bill
from orders O, yrb_customer C
where C.cid = O.cid
order by C.name, C.city, day, time;


-- What is the total weight of each order?
with weights (cid, when, grams) as (
		select P.cid, P.when, sum(B.weight * P.qnty) as grams
		from yrb_purchase P, yrb_book B
		where P.title = B.title and P.year = B.year
		group by P.cid, P.when
	)
select C.name, C.city,
	   cast (W.when as date) as day, cast (W.when as time) as time,
	   W.grams
from weights W, yrb_customer C
where W.cid = C.cid
order by W.grams desc, C.name;


-- What is the bill for each order, with the shipping cost added?
-- If the weight is X grams, 
-- the entry just higher than (or equal to) X is found in the shipping table 
-- and the associated shipping price is added.
with weights (cid, when, grams) as (
		select P.cid, P.when, sum(B.weight * P.qnty) as grams
		from yrb_purchase P, yrb_book B
		where P.title = B.title and P.year = B.year
		group by P.cid, P.when
	),
	 orders (cid, when, bill) as (
		select P.cid, P.when, sum(O.price * P.qnty) as bill
		from yrb_purchase P, yrb_offer O
		where P.club = O.club and P.title = O.title and P.year = O.year
		group by P.cid, P.when
	)	
select C.name, C.city, 
	   cast (O.when as date) as day, cast (O.when as time) as time, 
	   cast (O.bill as decimal(5,2)) as bill,
	   cast (O.bill as decimal(5,2)) + S.cost as total
from orders O, weights W, yrb_shipping S, yrb_customer C
where C.cid = O.cid and C.cid = W.cid and O.when = W.when and
	  S.weight = (select min(SS.weight)
				  from yrb_shipping SS
				  where SS.weight >= W.grams)
order by C.name, C.city, day, time;
	

-- For each droppable club, how much more money (or less!) would YRB have made if that club had never existed?
with replacable_best (cid, club, title, year, lowest) as (
		select P.cid, P.club, P.title, P.year, min(O.price) as lowest
		from yrb_purchase P, yrb_offer O, yrb_member M
		where P.club <> O.club and P.title = O.title and P.year = O.year and
			  M.cid = P.cid and M.club = O.club
		group by P.cid, P.club, P.title, P.year
	)
select C.club, sum((RB.lowest-OO.price)*PP.qnty) as savings
from yrb_club C, yrb_purchase PP, yrb_offer OO, replacable_best RB
where not exists (select P.cid, P.club, P.title, P.year
				 from yrb_purchase P
				 where P.club = C.club
				 except
				 select RB0.cid, RB0.club, RB0.title, RB0.year
				 from replacable_best RB0) and
	  PP.club = C.club and PP.club = OO.club and PP.title = OO.title and PP.year = OO.year and
	  RB.club = C.club and RB.title = PP.title and RB.year = PP.year and RB.cid = PP.cid
group by C.club
order by C.club;


connect reset;
terminate;
