USE sql_project;

SELECT * FROM netflix_raw;

--remove duplicates
--Checking duplicates for show_id
SELECT show_id, COUNT(*)
FROM netflix_raw
GROUP BY show_id
HAVING COUNT(*)>1;



--Checking duplicates for title
SELECT * FROM netflix_raw
WHERE CONCAT(UPPER(title),type) in (
SELECT CONCAT(UPPER(title),type)
FROM netflix_raw
GROUP BY UPPER(title), type
HAVING COUNT(*)>1 
)
ORDER BY title;

--Handling duplicates for title
with cte as(
SELECT *, ROW_NUMBER() OVER(PARTITION BY title, type ORDER BY show_id) AS rn
FROM netflix_raw
)
SELECT show_id, type, title,cast(date_added AS date) AS date_added,release_year,
       rating,CASE WHEN duration IS NULL THEN rating ELSE duration END AS DURATION,description
FROM cte 
WHERE rn = 1;


with cte as(
SELECT *, ROW_NUMBER() OVER(PARTITION BY title, type ORDER BY show_id) AS rn
FROM netflix_raw
)
SELECT show_id, type, title,cast(date_added AS date) AS date_added,release_year,
       rating,CASE WHEN duration IS NULL THEN rating ELSE duration END AS DURATION,description
INTO netflix_stg
FROM cte;

SELECT * FROM netflix_stg

--New table for director,country, cast, listed_in

--Spliting the directors name to different columns
SELECT show_id, trim(value) as director
into netflix_directors
FROM netflix_raw
CROSS APPLY string_split(director, ',');

SELECT * FROM netflix_directors;

--Spliting the country name to different columns
SELECT show_id, trim(value) as country
into netflix_country
FROM netflix_raw
CROSS APPLY string_split(country, ',');

SELECT * FROM netflix_country;

--Spliting the cast name to different columns
SELECT show_id, trim(value) as cast
into netflix_cast
FROM netflix_raw
CROSS APPLY string_split(cast, ',');

SELECT * FROM netflix_cast;

--Spliting the listed_in name to different columns
SELECT show_id, trim(value) as listed_in
into netflix_listed_in
FROM netflix_raw
CROSS APPLY string_split(listed_in, ',');

SELECT * FROM netflix_listed_in;

--Data type conversion for date_added


--Populate the missing values in country, duration column
insert into netflix_country
SELECT show_id, m.country
FROM netflix_raw nr
INNER JOIN (
SELECT director, country
FROM netflix_country nc
INNER JOIN netflix_directors nd ON nc.show_id = nd.show_id
GROUP BY director, country
) m ON nr.director = m.director
WHERE nr.country IS NULL;


--Netflix Data Analysis
/* For each director count the number of movies and tv shows created by them in seperate columns for directors
who have created tv shows and movies both*/

SELECT nd.director,
 COUNT(DISTINCT CASE WHEN n.type = 'Movie' THEN n.show_id END) AS no_of_movies,
 COUNT(DISTINCT CASE WHEN n.type = 'TV Show' THEN n.show_id END) AS no_of_TV_show
FROM netflix_stg n
INNER JOIN netflix_directors nd 
ON n.show_id = nd.show_id
GROUP BY nd.director
HAVING COUNT(DISTINCT n.type) > 1;

/* Which country has highes comedy movies*/
SELECT TOP 1 nc.country, COUNT(DISTINCT ng.show_id) AS no_of_movies
FROM netflix_listed_in ng
INNER JOIN netflix_country nc ON ng.show_id=nc.show_id
INNER JOIN netflix_stg n ON ng.show_id=nc.show_id
WHERE ng.listed_in='Comedies' AND n.type = 'Movie'
GROUP BY nc.country
ORDER BY no_of_movies DESC;


--What is average duration of movies in each gener
SELECT ng.listed_in, AVG(CAST(REPLACE(duration, 'min', '') AS int)) AS avg_duration
FROM netflix_stg n
INNER JOIN netflix_listed_in ng
ON n.show_id=ng.show_id
WHERE type='Movie'
GROUP BY ng.listed_in;

--Find the list of directors who have created horror and comedy movies both
SELECT nd.director,
COUNT(DISTINCT CASE WHEN ng.listed_in= 'Comedies' THEN n.show_id END) AS no_of_comedy,
COUNT(DISTINCT CASE WHEN ng.listed_in= 'Horror Movies' THEN n.show_id END) AS no_of_horror
FROM netflix_stg n
INNER JOIN netflix_listed_in ng ON n.show_id=ng.show_id
INNER JOIN netflix_directors nd ON n.show_id=nd.show_id
WHERE type='Movie' AND ng.listed_in IN ('Comedies','Horror Movies')
GROUP BY nd.director
HAVING COUNT(DISTINCT ng.listed_in)=2;


