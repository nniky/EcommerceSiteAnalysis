/*
 The following queries are all about analysing a website performance. It looks at analysing 
 1. top website pages,
 2. bounce rates
 3. analysing a/b tests,
 4. analysing the conversion funnel, 
 5. analysing websitetraffic
 6. analysing channel portfolio management
 7. analysing business patterns and seasonality
 8. product analysis 
 9. user analysis etc
 all in a mock up e-commerce site.
 */
 
 
/*
EXAMPLE 1
This query simply gets the most viewed website pages ranked by session volume.
It is just a simple single table query
*/
SELECT 
	pageview_url,
    COUNT(DISTINCT website_pageview_id) AS sessions
FROM website_pageviews
WHERE created_at < '2012-06-09'
GROUP BY pageview_url
ORDER BY sessions DESC;


/* 
USING temporary tables to run more complex queries:
EXAMPLE 2
attempting to find out which are the top landing/entry pages that customers come to when they first view the website.
Knowing this can help companies know which pages to spend time and money optimizing.
To query this I have made use of a temporary table as a first step to determine which are the first pageviews for each session. Then using that output
I have joined it back to the website pageviews table to find the url that the customer sees on that first page view.
*/
-- STEP 1 finding the first pageview for each session:
CREATE TEMPORARY TABLE landing_page_views
	SELECT 
		website_session_id,
		MIN(website_pageview_id) AS first_page_view
	FROM website_pageviews
	WHERE created_at < '2012-06-12'
	GROUP BY website_session_id;

-- STEP 2 finding the url the customer saw on the first page view
SELECT 
	website_pageviews.pageview_url AS landing_page,
    COUNT(DISTINCT landing_page_views.website_session_id) AS sessions
FROM landing_page_views
LEFT JOIN 
	website_pageviews 
    ON landing_page_views.first_page_view = website_pageviews.website_pageview_id
GROUP BY landing_page
ORDER BY sessions DESC;



/*
EXAMPLE 3.
The below was a tricky example. The objective was to find out how the home landing page 
was performing given that was where all of the customers were landing on first. The performance
was being evaluated by the bounced_rate i.e how many users were dropping off after landing on the home
landing page.

It was a series of steps and creation of multiple temp tables with each step leading closer to the output.

*/
-- STEP 1 - finding the first website_pageview_id for each session.
CREATE TEMPORARY TABLE landing_page_sessions
	SELECT 
		website_session_id,
		MIN(website_pageview_id) AS first_pageview_id
	FROM website_pageviews
	WHERE created_at < '2012-06-14'
	GROUP BY website_session_id;
    
-- STEP 2: identidying the landing page for each session
CREATE TEMPORARY TABLE landing_page_urls
SELECT 
	website_pageviews.pageview_url AS landing_page,
    landing_page_sessions.website_session_id AS landing_page_session_ids
FROM landing_page_sessions
LEFT JOIN 
	website_pageviews 
    ON landing_page_sessions.first_pageview_id = website_pageviews.website_pageview_id
WHERE landing_page_sessions.website_session_id = '/home';


-- step 3 : find out how many pageviews each of these sessions had to determine if they were bounced or not.
CREATE TEMPORARY TABLE bounced_sessions
SELECT 
	landing_page_urls.landing_page,
    landing_page_urls.landing_page_session_ids,
	COUNT(website_pageviews.website_pageview_id) AS bounced_sessions
FROM landing_page_urls
LEFT JOIN 
	website_pageviews
    ON landing_page_urls.landing_page_session_ids = website_pageviews.website_session_id
GROUP BY landing_page_urls.landing_page,
		landing_page_urls.landing_page_session_ids;

-- STEP 4 - summarizing the results to counting only the number of bounced sessions(i.e. dropping off after one website session)
SELECT 
	landing_page,
    COUNT(landing_page_session_ids) AS Number_of_sessions,
    COUNT(CASE WHEN bounced_sessions = 1 THEN bounced_sessions ELSE NULL END) AS number_of_bounced_sessions,
	COUNT(CASE WHEN bounced_sessions = 1 THEN bounced_sessions ELSE NULL END)/COUNT(landing_page_session_ids) AS Bounce_Rate
FROM bounced_sessions
GROUP BY landing_page


/*
EXAMPLE 4
Another challenging task was getting the volume of paidsearch non brand traffic landing on home and lander trending weekly.
and also the overall paid search bounce rate trended weekly.
This I did in 3 steps
Step 1 - determining the first pageview id for all sessions between June 1st and august 31 and coming from paid nonbranded 
search and counting how many pages were viewed in each session.
Step 2 - etermining which landing page the first pageview id relates to and also getting the dates
when the session was created so we can later group by week
Step 3 - lastly was just to summarize the results in a trending weekly analysis
*/

/* step 1: determining the first pageview id for all sessions between June 1st and august 31
and coming from paid nonbranded search and counting how many pages were viewed in each session.
*/
CREATE TEMPORARY TABLE first_pageviews_June_August
SELECT 
	website_pageviews.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS first_pageview,
    COUNT(website_pageviews.website_pageview_id) AS number_pages_viewed
FROM website_pageviews
LEFT JOIN website_sessions 
	ON website_pageviews.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-08-31' 
    AND website_sessions.created_at >= '2012-06-01'
    AND website_sessions.utm_source = 'gsearch'
    AND website_sessions.utm_campaign = 'nonbrand'
GROUP BY website_session_id;


/* step 2: determining which landing page the first pageview id relates to and also getting the dates
when the session was created so we can later group by week
*/
CREATE TEMPORARY TABLE first_pageview_url
SELECT 
	first_pageviews_June_August.website_session_id,
    first_pageviews_June_August.first_pageview,
    first_pageviews_June_August.number_pages_viewed,
    website_pageviews.pageview_url,
    website_pageviews.created_at
FROM first_pageviews_June_August
	LEFT JOIN website_pageviews ON first_pageviews_June_August.first_pageview = website_pageviews.website_pageview_id;

select * from first_pageview_url;

/* step 3 Getting the volume of paidsearch non brand traffic landing on home and lander trending weekly.
and also the overall paid search bounce rate trended weekly.
*/
SELECT 
	WEEK(created_at) AS weeknumber,
    MIN(DATE(created_at)) AS weekstart,
    COUNT(DISTINCT CASE WHEN number_pages_viewed = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT website_session_id) AS bounce_rate,
    COUNT(DISTINCT CASE WHEN pageview_url = '/home' THEN website_session_id ELSE NULL END) AS sessions_landing_home,
    COUNT(DISTINCT CASE WHEN pageview_url = '/lander-1' THEN website_session_id  ELSE NULL END) AS sessions_landing_lander
FROM first_pageview_url
GROUP BY weeknumber;


/*
EXAMPLE 5
this was to analyze the full conversion funnel of visitors from lander-1 focused on mrfuzzybear
*/

/*
 Step 1: first create a subquery that will get the website sessions and their corresponding pageview_urls
limit this ofcourse only for the paid gsearch customers and the time we are doing the analysis.
Then use the subquery to quantify in separate columns each of the pages visited and group the results in a temp table
*/


CREATE TEMPORARY TABLE conversion_funnel_lander1
SELECT
	DISTINCT website_session_id,
    CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE NULL END as lander1_page,
	CASE WHEN pageview_url = '/products' THEN 1 ELSE NULL  END as products_page,
    CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE NULL END as original_mrfuzzy_page,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE NULL END as cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE NULL END as shipping_page,
    CASE WHEN pageview_url = '/billing' THEN 1 ELSE NULL END as billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE NULL END as order_confirmed_page
FROM
(SELECT
	website_sessions.website_session_id,
    website_pageviews.pageview_url 
FROM website_sessions
LEFT JOIN website_pageviews ON website_sessions.website_session_id = website_pageviews.website_session_id
	WHERE utm_source = 'gsearch' 
		AND website_sessions.created_at > '2012-08-05'
        AND website_sessions.created_at < '2012-09-05') AS pagesviewed_per_session
ORDER BY website_session_id;

/*
Step 2: is to get a summary level data of the above.
*/
SELECT 
	COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(lander1_page) AS lander1page_clicks,
	COUNT(products_page) AS productpage_clicks,
    COUNT(original_mrfuzzy_page) AS original_mrfuzzy_page_clicks,
    COUNT(cart_page) AS cart_page_clicks,
    COUNT(shipping_page) AS shipping_page_clicks,
    COUNT(billing_page) AS billing_page_clicks,
    COUNT(order_confirmed_page) AS order_confirmed
FROM conversion_funnel_lander1;

SELECT 
	COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(products_page)/COUNT(DISTINCT website_session_id) as lander_clickthrough_rate,
    COUNT(original_mrfuzzy_page)/COUNT(products_page) AS product_clickthrough_rate,
    COUNT(cart_page)/COUNT(original_mrfuzzy_page) as mrfuzzy_clickthrough_rate,
    COUNT(shipping_page)/COUNT(cart_page) AS cart_clickthrough_rate,
	COUNT(billing_page)/COUNT(shipping_page) AS shipping_clickthrough_rate,
	COUNT(order_confirmed_page)/COUNT(billing_page) AS billing_clickthrough_rate
FROM conversion_funnel_lander1;


/*
EXAMPLE 6
Testing the performance of a new billing page to see what % of those pages end up placing
an order
*/
-- Step 1 is to find the date when billing-2 page was up and running so the analysis is like for like
SELECT 
	min(website_pageview_id),
    min(date(created_at))
FROM website_pageviews
WHERE pageview_url = '/billing-2';

-- date billing-2 created was 2012-09-10
-- pageview_id = 53550


-- Step 2
CREATE TEMPORARY TABLE sessions_and_pages_viewed
SELECT 
	website_pageviews.website_session_id,
    website_pageviews.pageview_url,
    order_id
FROM website_pageviews
LEFT JOIN orders ON website_pageviews.website_session_id = orders.website_session_id
	WHERE website_pageviews.created_at > '2012-09-10'
    AND website_pageviews.created_at < '2012-11-10'
    AND website_pageviews.pageview_url IN ('/billing','/billing-2')
    ORDER BY website_pageviews.website_session_id;

-- step 3 - summarizing results
SELECT
	sessions_and_pages_viewed.pageview_url,
	COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(order_id) AS orders,
	COUNT(order_id)/COUNT(DISTINCT website_session_id) AS billing_order_rate
FROM sessions_and_pages_viewed
GROUP BY sessions_and_pages_viewed.pageview_url;


/*
Example 7: 
The objective is to pull monthly trends for gsearch sessions and orders so that we can showcase the growth
*/
SELECT 
	YEAR(website_sessions.created_at) AS year,
    MONTH(website_sessions.created_at) AS month,
	COUNT(DISTINCT website_sessions.website_session_id) AS gsearch_sessions,
	COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS CVR
FROM website_sessions
LEFT JOIN orders ON website_sessions.website_session_id = orders.website_session_id
WHERE 	website_sessions.created_at < '2012-11-27' AND 
		website_sessions.utm_source = 'gsearch'
GROUP BY 1,2;

/*
Example 8:
The objective is to pull a similar monthly trend for Gsearch, but this time splitting out nonbrand 
and brand campaigns separately. This is to see if brand is picking up any traffic at all
*/

SELECT
	year,
    month,
    brand_sessions,
    brand_orders,
    brand_orders/brand_sessions AS cvr_brand_campaign,
	nonbrand_sessions,
    nonbrand_orders,
    nonbrand_orders/nonbrand_sessions AS cvr_nonbrand_campaign
FROM
(SELECT 
	YEAR(website_sessions.created_at) AS year,
    MONTH(website_sessions.created_at) AS month,
	COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN website_sessions.website_session_id ELSE NULL END) AS brand_sessions,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN orders.order_id ELSE NULL END) AS brand_orders,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN website_sessions.website_session_id ELSE NULL END) AS nonbrand_sessions,
	COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END) AS nonbrand_orders
FROM website_sessions
LEFT JOIN orders ON website_sessions.website_session_id = orders.website_session_id
WHERE 	website_sessions.created_at < '2012-11-27' AND 
		website_sessions.utm_source = 'gsearch'
GROUP BY 1,2) AS cvr_brandingcampaign;


/*
Example 9:
The objective is to tell the story of website performance improvements over the course of the first 8 months 
This would be best done by pull session to order conversion rates, by month
*/
SELECT 
	YEAR(website_sessions.created_at) AS year,
    MONTH(website_sessions.created_at) AS month,
    COUNT(website_sessions.website_session_id) AS totalsessions,
    COUNT(orders.order_id) as totalorders,
    COUNT(orders.order_id)/COUNT(website_sessions.website_session_id)
FROM website_sessions 
LEFT JOIN orders ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-11-27'
GROUP BY 1,2;

/*
Example 10:
This was a tricky one. The objective was to estimate the revenue that the gsearch lander test carries out
before earned the company.
I broke this down into a couple of steps
- step 1 - determine when the lander-1 page was first introduced so the analysis is fair fight
- Step 2 - determine the first page view id of each website session for gsearch, nonbranded in the respective dates
- Step 3 - determine what landing page that id refers to limiting to home and lander-1D
- Step 4 - link to orders and count the number of total sessions versus orders i.e. CVR for boths
- Step 5 - look at the incremental cvr so we know how much more sessions are being converted to orders
- Step 6 - Find out when the last lander went to home
- Step 7 -  then we total revenue since then to 27th Nov 2012 (limit of analysis) and use this and the lift in 
CVR to estimate incremental revenues.
*/

-- step 1 - determine when the lander-1 page was first introduced so the analysis is fair fight
SELECT
	MIN(website_pageview_id),
    MIN(created_at)
FROM 
	website_pageviews 
WHERE pageview_url = '/lander-1';

-- website_pageview_id = 23504 and date was 19th June 2012

-- Step 2 - determine the first page view id of each website session for gsearch, nonbranded in the respective dates
CREATE TEMPORARY TABLE min_pageviews
SELECT 
	website_pageviews.website_session_id,
	MIN(website_pageviews.website_pageview_id) AS min_pageview_id
FROM website_pageviews
INNER JOIN website_sessions
	ON website_sessions.website_session_id = website_pageviews.website_session_id
    AND website_sessions.created_at < '2012-07-28'
    AND website_pageviews.website_pageview_id >= 23504
    AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'
GROUP by website_sessions.website_session_id;


-- Step 3 - determine what landing page that id refers to limiting to home and lander-1D
CREATE TEMPORARY TABLE landing_pages
SELECT
	min_pageviews.website_session_id,
    website_pageviews.pageview_url AS landing_page
FROM min_pageviews
LEFT JOIN website_pageviews 
	on min_pageviews.min_pageview_id = website_pageviews.website_pageview_id
WHERE pageview_url IN ('/home','/lander-1');
	

-- Step 4 - link to orders and count the number of total sessions versus orders i.e. CVR for boths
CREATE TEMPORARY TABLE landing_pages_with_orders
SELECT
	landing_pages.website_session_id,
    landing_pages.landing_page,
    orders.order_id AS order_id
FROM landing_pages
LEFT JOIN orders
	ON orders.website_session_id = landing_pages.website_session_id;
    
    
-- Step 5 - look at the incremental cvr so we know how much more sessions are being converted to orders
SELECT 
	landing_page,
	COUNT(DISTINCT landing_pages_with_orders.website_session_id),
    COUNT(DISTINCT landing_pages_with_orders.order_id),
    COUNT(DISTINCT landing_pages_with_orders.order_id)/COUNT(DISTINCT landing_pages_with_orders.website_session_id)
FROM landing_pages_with_orders
GROUP BY landing_page;

-- CVR for home is 0.0318 while for /lander it is 0.0406. So the incremental conversion is 0.0088

-- Step 6 - Find out when the last lander went to home
SELECT
	MAX(website_sessions.website_session_id) AS most_recent_home_entry_page_vist
FROM website_sessions
	LEFT JOIN website_pageviews
		ON website_pageviews.website_session_id = website_sessions.website_session_id
WHERE utm_source = 'gsearch'
	AND utm_campaign = 'nonbrand'
	AND pageview_url = '/home'
    AND website_pageviews.created_at < '2012-11-27';
    
-- The latest website session was 17145
    

-- Step 7 -  then we total revenue since then to the date of analaysis 27-11-2012.
SELECT 
	COUNT(DISTINCT website_sessions.website_session_id)
FROM website_sessions
WHERE 
	website_sessions.created_at < '2012-11-27'
   AND website_sessions.website_session_id > 17145
   AND utm_source = 'gsearch'
   AND utm_campaign = 'nonbrand';

/*
22972 website sessions since the test. If the incremental CVR is 0.0088 then the 
number of orders are approximately 202.
If the average order value from the test to the date of analysis is ~50 as given by below query
then the estimated revenue earned from the test is c. $10,100
*/

SELECT 
	AVG(price_usd)
FROM order_items
WHERE created_at < '2012-11-27' AND created_at > '2012-07-29';

/*
Example 11: 
Objective is to show a full conversion funnel for the landing page test analysed before from each of the landers to 
orders
*/

CREATE TEMPORARY TABLE funnel_performance_per_session
SELECT 
	website_session_id,
    MAX(saw_home_page) AS saw_home_page,
    MAX(saw_lander1_page) AS saw_custom_lander_page,
    MAX(products_page) AS product_page,
    MAX(mr_fuzzy_page) AS mr_fuzzy_page,
    MAX(cart_page) AS cart_page,
    MAX(shipping_page) AS shipping_page,
    MAX(billing_page) AS billing_page,
    MAX(orderconfirmation_page) AS order_confirmation_page
FROM
(SELECT 
	website_sessions.website_session_id,
    website_pageviews.pageview_url,
    CASE WHEN website_pageviews.pageview_url = '/home' THEN 1 ELSE 0 END saw_home_page,
    CASE WHEN website_pageviews.pageview_url = '/lander-1' THEN 1 ELSE 0 END saw_lander1_page,
    CASE WHEN website_pageviews.pageview_url = '/products' THEN 1 ELSE 0 END products_page,
    CASE WHEN website_pageviews.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END mr_fuzzy_page,
    CASE WHEN website_pageviews.pageview_url = '/cart' THEN 1 ELSE 0 END cart_page,
    CASE WHEN website_pageviews.pageview_url = '/shipping' THEN 1 ELSE 0 END shipping_page,
    CASE WHEN website_pageviews.pageview_url = '/billing' THEN 1 ELSE 0 END billing_page,
    CASE WHEN website_pageviews.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END orderconfirmation_page
FROM website_sessions
	LEFT JOIN website_pageviews
		ON website_pageviews.website_session_id = website_sessions.website_session_id
	WHERE
		website_sessions.created_at > '2012-06-19'
        AND website_sessions.created_at < '2012-07-28'
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand') AS funnel_analysis
GROUP BY 
	1
        ;

-- Step 2: Bring the two tables together to get summary 
CREATE TEMPORARY TABLE click_through_session_level
SELECT
    CASE WHEN saw_home_page = 1 THEN 'saw_home_page' 
		WHEN saw_custom_lander_page = 1 THEN 'saw_custom_lander_page'
		ELSE 'check_logic' END AS landing_page_seen,
    COUNT(DISTINCT funnel_performance_per_session.website_session_id) AS sessions,
    COUNT(CASE WHEN funnel_performance_per_session.product_page = 1 THEN 1 ELSE NULL END) AS clicks_to_product_page,
    COUNT(CASE WHEN funnel_performance_per_session.mr_fuzzy_page = 1 THEN 1 ELSE NULL END) AS clicks_to_mr_fuzzy_page,
    COUNT(CASE WHEN funnel_performance_per_session.cart_page = 1 THEN 1 ELSE NULL END) AS clicks_to_cart_page,
    COUNT(CASE WHEN funnel_performance_per_session.shipping_page = 1 THEN 1 ELSE NULL END) AS clicks_to_shipping_page,
    COUNT(CASE WHEN funnel_performance_per_session.billing_page = 1 THEN 1 ELSE NULL END) AS clicks_to_billing,
    COUNT(CASE WHEN funnel_performance_per_session.order_confirmation_page = 1 THEN 1 ELSE NULL END) AS clicks_to_order_confirmation
FROM funnel_performance_per_session
GROUP BY 1;

-- STEP 3: group data to see click rates
SELECT 
	landing_page_seen,
    clicks_to_product_page/sessions AS lander_click_rate,
    clicks_to_mr_fuzzy_page/clicks_to_product_page AS product_click_rate,
    clicks_to_cart_page/clicks_to_mr_fuzzy_page AS mr_fuzzy_page_click_rt,
    clicks_to_shipping_page/clicks_to_cart_page AS cart_click_rate,
    clicks_to_billing/clicks_to_shipping_page AS shipping_click_rt,
    clicks_to_order_confirmation/clicks_to_billing AS billing_click_rate
FROM click_through_session_level;


/*
Example 12: 
The objective was to quantify the impact of the billing test done earlier as well. Analysing the lift generated 
from the test (Sep 10 – Nov 10), in terms of revenue per billing page session, and then pulling the number 
of billing page sessions for the past month to understand monthly impact.
I did this in 3 steps
-- step 1: get all the sessions that saw billing or billing2
-- step 2: join to orders to see the total revenues and to calculatie the revenue per billing session
-- step 3: count number of website sessions making it to billing for the past month and quantify monthly impact
*/

SELECT	
	billing_page_seen,
    COUNT(DISTINCT website_session_id),
    SUM(price_usd)/COUNT(DISTINCT website_session_id) AS revenue_per_billing_session
FROM
(SELECT
	website_pageviews.website_session_id as website_session_id,
    website_pageviews.pageview_url as billing_page_seen,
    orders.order_id,
    orders.price_usd
FROM website_pageviews
	LEFT JOIN orders
		ON orders.website_session_id = website_pageviews.website_session_id
WHERE website_pageviews.created_at > '2012-09-10'
	AND website_pageviews.created_at < '2012-11-10'
    AND website_pageviews.pageview_url IN ('/billing','/billing-2')) 
    AS billing_pages
GROUP BY 1;

-- the old billing page generated $22.83 per session
-- While the new billing page generates $31.34 per session
-- The lift therefore is $8.51 per session

SELECT 
	COUNT(website_session_id) as billing_sessions_last_month
FROM website_pageviews
WHERE pageview_url IN ('/billing','/billing-2')
AND website_pageviews.created_at BETWEEN '2012-10-27' AND '2012-11-27';

-- 1193 billing sessions this month. 
-- Therefore the monthly impact would be c.$10,152 lift/ $37,389 in revenue.


-- Example 13:
SELECT
	MIN(date(created_at)) AS week_start_date,
    COUNT(CASE WHEN utm_source = 'gsearch' THEN website_sessions.website_session_id ELSE NULL END) AS gsearch_sessions,
	COUNT(CASE WHEN utm_source = 'bsearch' THEN website_sessions.website_session_id ELSE NULL END) AS bsearch_sessions
FROM
	website_sessions
WHERE website_sessions.created_at > '2012-08-22'
	AND website_sessions.created_at < '2012-11-29'
    AND utm_campaign = 'nonbrand'
GROUP BY WEEK(created_at);

-- Example 14:
SELECT 
	utm_source,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' then website_session_id ELSE NULL END) AS mobile_sessions,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' then website_session_id ELSE NULL END)/COUNT(DISTINCT website_sessions.website_session_id) AS pct_mobile
FROM website_sessions
WHERE created_at > '2012-08-22'
	AND created_at < '2012-11-30'
    AND utm_campaign = 'nonbrand'
GROUP BY utm_source;


-- Example 15:
SELECT 
	YEAR(created_at) as yr,
    MONTH(created_at) AS mnth,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' AND utm_source IS NOT NULL THEN website_session_id ELSE NULL END) AS nonbrand,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' AND utm_source IS NOT NULL THEN website_session_id ELSE NULL END) AS brand,
		COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' AND utm_source IS NOT NULL THEN website_session_id ELSE NULL END)/
        COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' AND utm_source IS NOT NULL THEN website_session_id ELSE NULL END) AS brand_pct_of_nonbrand,
	COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN website_session_id ELSE NULL END) AS direct_traffic,
		COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN website_session_id ELSE NULL END) /
		COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' AND utm_source IS NOT NULL THEN website_session_id ELSE NULL END) AS direct_pct_of_nonbrand,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN website_session_id ELSE NULL END) AS organic_search,
		COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN website_session_id ELSE NULL END)/
        COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' AND utm_source IS NOT NULL THEN website_session_id ELSE NULL END) AS organic_pct_of_nonbrand
FROM website_sessions
WHERE created_at < '2012-12-23'
GROUP BY 1, 2;

-- Example 16
SELECT
	YEAR(website_sessions.created_at) AS yr,
    MONTH(website_sessions.created_at) AS mnth,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders
FROM website_sessions
	LEFT JOIN orders ON 
		orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2013-01-01'
GROUP BY 1, 2;

-- Example 17:
SELECT
	MIN(DATE(website_sessions.created_at)) AS week_start,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders
FROM website_sessions
	LEFT JOIN orders ON 
		orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2013-01-01'
GROUP BY WEEK(website_sessions.created_at);

-- Example 18:
SELECT
	hr,
    ROUND(AVG(CASE WHEN week = 0 THEN sessions ELSE NULL END),1) AS mon,
	ROUND(AVG(CASE WHEN week = 1 THEN sessions ELSE NULL END),1) AS tue,
    ROUND(AVG(CASE WHEN week = 2 THEN sessions ELSE NULL END),1) AS wed,
    ROUND(AVG(CASE WHEN week = 3 THEN sessions ELSE NULL END),1) AS thurs,
    ROUND(AVG(CASE WHEN week = 4 THEN sessions ELSE NULL END),1) AS fri,
    ROUND(AVG(CASE WHEN week = 5 THEN sessions ELSE NULL END),1) AS sat,
    ROUND(AVG(CASE WHEN week = 6 THEN sessions ELSE NULL END),1) AS sun
FROM
(SELECT 
	DATE(created_at) AS day,
	WEEKDAY(created_at) AS week,
	HOUR(created_at) AS hr,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-09-15' AND '2012-11-16'
GROUP BY 1,2,3) as daily_sessions
GROUP BY 1
ORDER BY 1;


-- Example 19:
SELECT 
	YEAR(website_sessions.created_at) AS yr,
    MONTH(website_sessions.created_at) AS mo,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate,
    SUM(price_usd)/COUNT(DISTINCT website_sessions.website_session_id) AS revenue_per_session,
    COUNT(CASE WHEN primary_product_id = 1 THEN order_id ELSE NULL END) AS product_one_orders,
    COUNT(CASE WHEN primary_product_id = 2 THEN order_id ELSE NULL END) AS product_two_orders
FROM 
	website_sessions
LEFT JOIN orders ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at BETWEEN '2012-04-01' AND '2013-04-05'
GROUP BY 1,2;

/* Example 20:
-- In this analysis I looked to get an idea of how the clickthrough rates were looking after the launch of 
a new product at the maven fuzzy factory. It aims to see the sessions that hit the /product page and then analyse
where customers went next if they did. I also looked at the clickthrough rates comparing the sessions to each of the 
products 3 months before and upto 3 months after the launch of the second product. 
From this analysis it was evident that the clickthrough to the mr fuzzy bear product reduced however the number of 
customers going past the /product page increased. 
*/

CREATE TEMPORARY TABLE pages_viewed
SELECT
	time_period,
    website_session_id,
    MAX(product_page) AS to_product,
    MAX(product_1_page) AS to_product_1,
    MAX(product_2_page) AS to_product_2
FROM
(SELECT 
	CASE WHEN website_sessions.created_at < '2013-01-06' THEN 'A.pre_product_2'
		WHEN website_sessions.created_at >= '2013-01-06' THEN 'B.post_product_2' 
        ELSE NULL END AS time_period,
	website_sessions.website_session_id,
    website_pageviews.pageview_url,
    CASE WHEN website_pageviews.pageview_url = '/products' THEN 1 ELSE 0 END AS product_page,
    CASE WHEN website_pageviews.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS product_1_page,
    CASE WHEN website_pageviews.pageview_url = '/the-forever-love-bear' THEN 1 ELSE 0 END AS product_2_page
FROM website_sessions
	LEFT JOIN website_pageviews ON
		website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.created_at > '2012-10-06' 
AND website_sessions.created_at < '2013-04-06') AS pageview_flags
GROUP BY 1,2;

-- step 2 bring the above together in a summary
SELECT
	time_period,
    COUNT(CASE WHEN to_product = 1 THEN website_session_id ELSE NULL END) AS went_to_product_page,
	COUNT(CASE WHEN to_product_1 = 1 OR to_product_2 = 1 THEN website_session_id ELSE NULL END) AS went_to_next_page,
		COUNT(CASE WHEN to_product_1 = 1 OR to_product_2 = 1 THEN website_session_id ELSE NULL END)/COUNT(CASE WHEN to_product = 1 THEN website_session_id ELSE NULL END) as pct_w_next_page,
    COUNT(CASE WHEN to_product_1 = 1 THEN website_session_id ELSE NULL END) AS sessions_to_product_1_page,
		COUNT(CASE WHEN to_product_1 = 1 THEN website_session_id ELSE NULL END)/COUNT(CASE WHEN to_product = 1 THEN website_session_id ELSE NULL END) AS pct_w_product_1,
    COUNT(CASE WHEN to_product_2 = 1 THEN website_session_id ELSE NULL END) AS sessions_to_product_2_page,
		COUNT(CASE WHEN to_product_2 = 1 THEN website_session_id ELSE NULL END)/COUNT(CASE WHEN to_product = 1 THEN website_session_id ELSE NULL END) AS pct_w_product_1
FROM pages_viewed
GROUP BY time_period;


/*
Example 21: 
This axample was to analyse product specific conversion funnel comparing across two products the mr fuzzy bear and
a new product launched the forever bear
Such analysis is useful to analyse product performance, if addition of a new product is canibalizing the other product 
or being incremental to the overall business performance or if overall bottom lines are impacted negatively when 
customers have too many choices,
-- Step 1 flag the various pageviews
-- step 2 bring together the data in summary - volume based
-- Step 3 summary in a click through rate based table
From this analysis it was evident that the new product forever bear was a great addition to the offering
*/
-- Step 1
CREATE TEMPORARY TABLE product_and_pageviews_flagged
SELECT
	website_session_id,
	MAX(product) as product,
    MAX(sessions_flag) as sessions,
    MAX(cart_flag) as cart,
    MAX(shipping_flag) as shipping,
    MAX(billing_flag) as billing,
    MAX(thankyou_flag) as thankyou
FROM
(SELECT
	website_sessions.website_session_id,
    website_pageviews.pageview_url,
    CASE WHEN website_pageviews.pageview_url = '/the-original-mr-fuzzy' THEN 'mr_fuzzy' 
		WHEN website_pageviews.pageview_url = '/the-forever-love-bear' THEN 'forever_bear'
        ELSE NULL END as product,
	CASE WHEN pageview_url = '/the-original-mr-fuzzy' or pageview_url = '/the-forever-love-bear' THEN 1 ELSE 0 END AS sessions_flag,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END as cart_flag,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END as shipping_flag,
    CASE WHEN pageview_url = '/billing-1' or pageview_url = '/billing-2' THEN 1 ELSE 0 END as billing_flag,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_flag
	FROM website_sessions
		LEFT JOIN website_pageviews ON
			website_pageviews.website_session_id = website_sessions.website_session_id
	WHERE website_sessions.created_at > '2013-01-06'
		AND website_sessions.created_at < '2013-04-10') as pageview_flag
	GROUP BY 1;

    -- step 2
    SELECT 
		product,
        COUNT(CASE WHEN sessions = 1 THEN website_session_id ELSE NULL END) AS sessions,
        COUNT(CASE WHEN cart = 1 THEN website_session_id ELSE NULL END) AS to_cart,
        COUNT(CASE WHEN shipping = 1 THEN website_session_id ELSE NULL END) AS to_shipping,
        COUNT(CASE WHEN billing = 1 THEN website_session_id ELSE NULL END) AS to_billing,
        COUNT(CASE WHEN thankyou = 1 THEN website_session_id ELSE NULL END) AS to_confirmation
	FROM product_and_pageviews_flagged
    WHERE product IS NOT NULL
	GROUP BY product;
    
    -- step 3
    SELECT 
		product,
        COUNT(CASE WHEN cart = 1 THEN website_session_id ELSE NULL END)/COUNT(CASE WHEN sessions = 1 THEN website_session_id ELSE NULL END) AS product_page_click_rt,
		COUNT(CASE WHEN shipping = 1 THEN website_session_id ELSE NULL END)/COUNT(CASE WHEN cart = 1 THEN website_session_id ELSE NULL END) AS cart_click_rt,
        COUNT(CASE WHEN billing = 1 THEN website_session_id ELSE NULL END)/COUNT(CASE WHEN shipping = 1 THEN website_session_id ELSE NULL END) AS billing_click_rt,
        COUNT(CASE WHEN thankyou = 1 THEN website_session_id ELSE NULL END)/COUNT(CASE WHEN billing = 1 THEN website_session_id ELSE NULL END) AS confirmation_click_rt
	FROM product_and_pageviews_flagged
    WHERE product IS NOT NULL
	GROUP BY product;
    
    
    /*
    Example 22:
  This was an analysis to understanding cross selling. It is important to understand which products are often purchased
  together, or for testing and optimizing the way you cross sell on your website e.g what point should you suggest a complementary product
  It can also be useful to understand the conversion rate impact and overall revenue impact of try to cross sell additional products.
  
  In this example customers were given the option to add a 2nd product while on the /cart page from Sept25th 2013. This is 
  an analysis on ctr from cart page, avg products per order, average order value and reveue per cart page view
  for the month before the cross sell was introduced vs one month after. I did this in 3 steps:
-- Step 1 identify the relevant /cart page views, their sessions and flag which of those clicked through to shipping,
-- Step 2 find the orders associated with those /cart sessions. analyse products purchased, aov,
-- step 3 aggregate and analyse a summary of findings.
    */

-- Step 1 identify the relevant /cart page views, their sessions and flag which of those clicked through to shipping,
CREATE TEMPORARY TABLE cart_sessions_and_clickthroughs
SELECT
	time_period,
    website_session_id,
    MAX(cart_sessions_flag) AS cart_sessions,
    MAX(clickthroughs_flag) AS click_throughs
FROM
(SELECT 
	CASE WHEN created_at < '2013-09-25' THEN 'A.pre_cross_sell'
		WHEN created_at >= '2013-09-25' THEN 'B.pre_cross_sell'
        ELSE NULL END AS time_period,
	website_session_id,
	CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_sessions_flag,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS clickthroughs_flag
FROM website_pageviews
WHERE created_at BETWEEN '2013-08-25' AND '2013-10-25'
	AND pageview_url IN ('/cart','/shipping','/billing','/billing-2','thank-you-for-your-order')) AS cart_Sessions_withflags
GROUP BY 1,2;

-- Step 2 find the orders associated with those /cart sessions. analyse products purchased, aov
CREATE TEMPORARY TABLE cart_to_order_details
SELECT 
	time_period,
    cart_sessions_and_clickthroughs.website_session_id,
    cart_sessions,
    click_throughs,
	orders.items_purchased,
    orders.price_usd AS order_value
FROM cart_sessions_and_clickthroughs
LEFT JOIN orders ON
	orders.website_session_id = cart_sessions_and_clickthroughs.website_session_id;
    
-- step 3 aggregate and analyse a summary of findings
SELECT
	time_period,
    COUNT(CASE WHEN cart_sessions = 1 THEN website_session_id ELSE NULL END) AS cart_sessions,
    COUNT(CASE WHEN click_throughs = 1 THEN website_session_id ELSE NULL END) AS clickthroughs,
    COUNT(CASE WHEN click_throughs = 1 THEN website_session_id ELSE NULL END) /COUNT(CASE WHEN cart_sessions = 1 THEN website_session_id ELSE NULL END) as cart_ctr,
    AVG(items_purchased) AS products_per_order,
    AVG(order_value) AS aov,
    SUM(order_value)/COUNT(CASE WHEN cart_sessions = 1 THEN website_session_id ELSE NULL END) as revenue_per_cart_session
FROM cart_to_order_details
GROUP BY 1;

/*
Example 23:
this is a similar analysis to above on introducing a 3rd product for the birthday gift market. 
It was evident that the critical metrics showed improvement after the launch of the third product
*/
SELECT
	CASE WHEN website_sessions.created_at < '2013-12-12' THEN 'A.Pre_birthday_bear' 
		WHEN website_sessions.created_at >= '2013-12-12' THEN 'B.Post_birthday_bear'
        ELSE NULL END AS time_period,
    COUNT(DISTINCT orders.order_id)/ COUNT(DISTINCT website_sessions.website_session_id) as conv_rate,
    AVG(orders.price_usd) as order_value,
    AVG(orders.items_purchased) as products_per_order,
    SUM(orders.price_usd)/COUNT(DISTINCT website_sessions.website_session_id) as revenue_per_session
FROM website_sessions
	LEFT JOIN orders ON
		website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at BETWEEN '2013-11-12' AND '2014-01-12'
GROUP BY 1;

/*
Example 24:
This analysis was to understand refunds. there was a major quality issue of the supplier for the mr fuzzy bear
who was replaced at some point. The below analysis was to do a month by month analysis of orders and refunds of 
each product to have a sense check of those refund rates and also determine if indeed the quality issues were fixed
after the introduction of a new supplier. 
The analysis showed that it was the case with refund rates for the fuzzy bear dropping from as high as 13% to c.2%
*/
SELECT 
	YEAR(order_items.created_at) AS yr,
    MONTH(order_items.created_at) AS mnth,
    COUNT(CASE WHEN order_items.product_id = 1 THEN order_items.order_item_id ELSE NULL END) AS p1_orders,
		COUNT(CASE WHEN order_items.product_id = 1 THEN order_item_refunds.order_item_refund_id ELSE NULL END)/
        COUNT(CASE WHEN order_items.product_id = 1 THEN order_items.order_item_id ELSE NULL END) AS p1_refund_rt,
    COUNT(CASE WHEN order_items.product_id = 2 THEN order_items.order_item_id ELSE NULL END) AS p2_orders,
		COUNT(CASE WHEN order_items.product_id = 2 THEN order_item_refunds.order_item_refund_id ELSE NULL END)/
        COUNT(CASE WHEN order_items.product_id = 2 THEN order_items.order_item_id ELSE NULL END) AS p2_refund_rt,
	COUNT(CASE WHEN order_items.product_id = 3 THEN order_items.order_item_id ELSE NULL END) AS p3_orders,
		COUNT(CASE WHEN order_items.product_id = 3 THEN order_item_refunds.order_item_refund_id ELSE NULL END)/
        COUNT(CASE WHEN order_items.product_id = 3 THEN order_items.order_item_id ELSE NULL END) AS p3_refund_rt
FROM order_items
LEFT JOIN order_item_refunds ON
	order_items.order_item_id = order_item_refunds.order_item_id
WHERE order_items.created_at < '2014-10-15'
GROUP BY 1,2;



/*
-- Example 25:
Pulling monthly trends for revenue and margin by product, along with total margin and revenue
to understand if there is any seasonality in the data
The data showed the largest revenue & sales month to be November each year which is the  - pre-christmas holiday period 
(blackfriday, cybermonday and pre-christmas shopping) and then also 12 is quite substantial before
The data also showed that the business was  losing steam each year Jan and Feb. 
Sales slowly pick up through the year but pretty stagnant around mid year .
*/

SELECT
	YEAR(created_at) AS yr, 
    MONTH(created_at) AS mo, 
    SUM(CASE WHEN product_id = 1 THEN price_usd ELSE NULL END) AS mrfuzzy_rev,
    SUM(CASE WHEN product_id = 1 THEN price_usd - cogs_usd ELSE NULL END) AS mrfuzzy_marg,
    SUM(CASE WHEN product_id = 2 THEN price_usd ELSE NULL END) AS lovebear_rev,
    SUM(CASE WHEN product_id = 2 THEN price_usd - cogs_usd ELSE NULL END) AS lovebear_marg,
    SUM(CASE WHEN product_id = 3 THEN price_usd ELSE NULL END) AS birthdaybear_rev,
    SUM(CASE WHEN product_id = 3 THEN price_usd - cogs_usd ELSE NULL END) AS birthdaybear_marg,
    SUM(CASE WHEN product_id = 4 THEN price_usd ELSE NULL END) AS minibear_rev,
    SUM(CASE WHEN product_id = 4 THEN price_usd - cogs_usd ELSE NULL END) AS minibear_marg,
    SUM(price_usd) AS total_revenue,  
    SUM(price_usd - cogs_usd) AS total_margin
FROM order_items 
GROUP BY 1,2
ORDER BY 1,2


/*
-- Example 26:
This analysis was to dive deeper into the impact of introducing new products. 
Pulling monthly sessions to the /products page, and showing how the % of those sessions clicking through 
another page has changed over time, along with a view of how conversion from /products to placing an order has improved.
*/

CREATE TEMPORARY TABLE products_pageviews
SELECT
	website_session_id, 
    website_pageview_id, 
    created_at AS saw_product_page_at
FROM website_pageviews 
WHERE pageview_url = '/products';

SELECT 
	YEAR(saw_product_page_at) AS yr, 
    MONTH(saw_product_page_at) AS mo,
    COUNT(DISTINCT products_pageviews.website_session_id) AS sessions_to_product_page, 
    COUNT(DISTINCT website_pageviews.website_session_id) AS clicked_to_next_page, 
    COUNT(DISTINCT website_pageviews.website_session_id)/COUNT(DISTINCT products_pageviews.website_session_id) AS clickthrough_rt,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT products_pageviews.website_session_id) AS products_to_order_rt
FROM products_pageviews
	LEFT JOIN website_pageviews 
		ON website_pageviews.website_session_id = products_pageviews.website_session_id -- same session
        AND website_pageviews.website_pageview_id > products_pageviews.website_pageview_id -- they had another page AFTER
	LEFT JOIN orders 
		ON orders.website_session_id = products_pageviews.website_session_id
GROUP BY 1,2
;

/*
-- Example 27
The business introduced a 4th product on December 05, 2014 as a primary product. This analyses pull sales data since then
and show how well each product cross-sells from one another.
Product 4 definitely showed to be the best cross selling product.
*/

CREATE TEMPORARY TABLE primary_products
SELECT 
	order_id, 
    primary_product_id, 
    created_at AS ordered_at
FROM orders 
WHERE created_at > '2014-12-05' -- when the 4th product was added (says so in question)
;

SELECT
	primary_products.*, 
    order_items.product_id AS cross_sell_product_id
FROM primary_products
	LEFT JOIN order_items 
		ON order_items.order_id = primary_products.order_id
        AND order_items.is_primary_item = 0; -- only bringing in cross-sells;

SELECT 
	primary_product_id, 
    COUNT(DISTINCT order_id) AS total_orders, 
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END) AS _xsold_p1,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END) AS _xsold_p2,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END) AS _xsold_p3,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END) AS _xsold_p4,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p1_xsell_rt,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p2_xsell_rt,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p3_xsell_rt,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p4_xsell_rt
FROM
(
SELECT
	primary_products.*, 
    order_items.product_id AS cross_sell_product_id
FROM primary_products
	LEFT JOIN order_items 
		ON order_items.order_id = primary_products.order_id
        AND order_items.is_primary_item = 0 -- only bringing in cross-sells
) AS primary_w_cross_sell
GROUP BY 1;
