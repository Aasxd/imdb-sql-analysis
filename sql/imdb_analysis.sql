/* =====================================================================
   IMDb Movie Analysis for RSVP Movies
   ---------------------------------------------------------------------
   Author   : Mohammed Asad Khan
   Engine   : MySQL 8.0+ (uses CTEs and window functions)
   Database : imdb
   Tables   : movie, genre, ratings, names, director_mapping, role_mapping

   Structure
     Segment 1 - Data exploration (movie & genre tables)      Q1 - Q9
     Segment 2 - Ratings analysis                             Q10 - Q17
     Segment 3 - People: directors, actors, actresses         Q18 - Q24
     Segment 4 - Advanced analysis                            Q25 - Q29
   ===================================================================== */

USE imdb;


/* =====================================================================
   SEGMENT 1 - DATA EXPLORATION
   ===================================================================== */

-- Q1. Total number of rows in each table
SELECT 'movie'            AS table_name, COUNT(*) AS row_count FROM movie
UNION ALL
SELECT 'genre',            COUNT(*) FROM genre
UNION ALL
SELECT 'director_mapping', COUNT(*) FROM director_mapping
UNION ALL
SELECT 'role_mapping',     COUNT(*) FROM role_mapping
UNION ALL
SELECT 'names',            COUNT(*) FROM names
UNION ALL
SELECT 'ratings',          COUNT(*) FROM ratings;


-- Q2. Which columns in the movie table have NULL values?
SELECT
    SUM(title IS NULL)                 AS title_nulls,
    SUM(year IS NULL)                  AS year_nulls,
    SUM(date_published IS NULL)        AS date_published_nulls,
    SUM(duration IS NULL)              AS duration_nulls,
    SUM(country IS NULL)               AS country_nulls,
    SUM(worlwide_gross_income IS NULL) AS worldwide_gross_income_nulls,
    SUM(languages IS NULL)             AS languages_nulls,
    SUM(production_company IS NULL)    AS production_company_nulls
FROM movie;
-- Insight: country, worlwide_gross_income, languages and production_company contain NULLs.


-- Q3a. Number of movies released each year
SELECT
    year,
    COUNT(*) AS number_of_movies
FROM movie
GROUP BY year
ORDER BY year;

-- Q3b. Month-wise trend (all years combined)
SELECT
    MONTH(date_published) AS month_num,
    COUNT(*)              AS number_of_movies
FROM movie
GROUP BY MONTH(date_published)
ORDER BY month_num;
-- Insight: March has the highest number of releases.


-- Q4. Movies produced in the USA or India in 2019
-- The country column can hold several countries ("USA, UK"), so LIKE is used
-- instead of an exact match to avoid undercounting co-productions.
SELECT COUNT(DISTINCT id) AS number_of_movies
FROM movie
WHERE year = 2019
  AND (country LIKE '%USA%' OR country LIKE '%India%');


-- Q5. Unique list of genres
SELECT DISTINCT genre
FROM genre
ORDER BY genre;


-- Q6. Genre with the highest number of movies overall
SELECT
    genre,
    COUNT(movie_id) AS movie_count
FROM genre
GROUP BY genre
ORDER BY movie_count DESC
LIMIT 1;
-- Insight: Drama is the most produced genre.


-- Q7. How many movies belong to only one genre?
WITH single_genre_movies AS (
    SELECT movie_id
    FROM genre
    GROUP BY movie_id
    HAVING COUNT(DISTINCT genre) = 1
)
SELECT COUNT(*) AS single_genre_movie_count
FROM single_genre_movies;
-- Insight: more than 3,000 movies belong to a single genre.


-- Q8. Average duration of movies in each genre
SELECT
    g.genre,
    ROUND(AVG(m.duration), 2) AS avg_duration
FROM movie m
JOIN genre g ON m.id = g.movie_id
GROUP BY g.genre
ORDER BY avg_duration DESC;
-- Insight: Drama movies average 106.77 minutes.


-- Q9. Rank of the Thriller genre by number of movies produced
WITH genre_ranking AS (
    SELECT
        genre,
        COUNT(movie_id)                             AS movie_count,
        RANK() OVER (ORDER BY COUNT(movie_id) DESC) AS genre_rank
    FROM genre
    GROUP BY genre
)
SELECT *
FROM genre_ranking
WHERE genre = 'Thriller';
-- Insight: Thriller ranks 3rd.


/* =====================================================================
   SEGMENT 2 - RATINGS ANALYSIS
   ===================================================================== */

-- Q10. Minimum and maximum of each column in the ratings table
SELECT
    MIN(avg_rating)    AS min_avg_rating,
    MAX(avg_rating)    AS max_avg_rating,
    MIN(total_votes)   AS min_total_votes,
    MAX(total_votes)   AS max_total_votes,
    MIN(median_rating) AS min_median_rating,
    MAX(median_rating) AS max_median_rating
FROM ratings;
-- Insight: all values fall in the expected range, so there are no outliers.


-- Q11. Top 10 movies by average rating
WITH movie_ranking AS (
    SELECT
        m.title,
        r.avg_rating,
        DENSE_RANK() OVER (ORDER BY r.avg_rating DESC) AS movie_rank
    FROM movie m
    JOIN ratings r ON m.id = r.movie_id
)
SELECT *
FROM movie_ranking
WHERE movie_rank <= 10;


-- Q12. Movie counts by median rating
SELECT
    median_rating,
    COUNT(movie_id) AS movie_count
FROM ratings
GROUP BY median_rating
ORDER BY median_rating;
-- Insight: a median rating of 7 is the most common.


-- Q13. Production house with the most hit movies (average rating > 8)
SELECT
    m.production_company,
    COUNT(m.id)                                    AS movie_count,
    DENSE_RANK() OVER (ORDER BY COUNT(m.id) DESC)  AS prod_company_rank
FROM movie m
JOIN ratings r ON m.id = r.movie_id
WHERE r.avg_rating > 8
  AND m.production_company IS NOT NULL
GROUP BY m.production_company
ORDER BY movie_count DESC;
-- Insight: Dream Warrior Pictures and National Theatre Live tie for 1st.


-- Q14. Movies per genre released in March 2017 in the USA with more than 1,000 votes
SELECT
    g.genre,
    COUNT(m.id) AS movie_count
FROM movie m
JOIN genre   g ON m.id = g.movie_id
JOIN ratings r ON m.id = r.movie_id
WHERE m.date_published BETWEEN '2017-03-01' AND '2017-03-31'
  AND m.country LIKE '%USA%'
  AND r.total_votes > 1000
GROUP BY g.genre
ORDER BY movie_count DESC;


-- Q15. Movies starting with "The" with an average rating > 8, by genre
SELECT
    m.title,
    r.avg_rating,
    g.genre
FROM movie m
JOIN genre   g ON m.id = g.movie_id
JOIN ratings r ON m.id = r.movie_id
WHERE m.title LIKE 'The%'
  AND r.avg_rating > 8
ORDER BY g.genre, r.avg_rating DESC;


-- Q16. Movies released between 1 Apr 2018 and 1 Apr 2019 with a median rating of 8
SELECT COUNT(*) AS movie_count
FROM movie m
JOIN ratings r ON m.id = r.movie_id
WHERE m.date_published BETWEEN '2018-04-01' AND '2019-04-01'
  AND r.median_rating = 8;


-- Q17. Do German movies get more votes than Italian movies?
-- Sums total votes (not movie counts) and includes co-productions.
SELECT
    c.country,
    SUM(r.total_votes) AS total_votes
FROM (SELECT 'Germany' AS country UNION ALL SELECT 'Italy') AS c
JOIN movie   m ON m.country LIKE CONCAT('%', c.country, '%')
JOIN ratings r ON m.id = r.movie_id
GROUP BY c.country
ORDER BY total_votes DESC;
-- Insight: German movies receive more votes than Italian movies.


/* =====================================================================
   SEGMENT 3 - DIRECTORS, ACTORS & ACTRESSES
   ===================================================================== */

-- Q18. Which columns in the names table have NULL values?
SELECT
    SUM(name IS NULL)             AS name_nulls,
    SUM(height IS NULL)           AS height_nulls,
    SUM(date_of_birth IS NULL)    AS date_of_birth_nulls,
    SUM(known_for_movies IS NULL) AS known_for_movies_nulls
FROM names;
-- Insight: name has no NULLs; height, date_of_birth and known_for_movies do.


-- Q19. Top 3 directors in the top 3 genres (by movies with average rating > 8)
WITH top_genres AS (
    SELECT g.genre
    FROM genre g
    JOIN ratings r ON g.movie_id = r.movie_id
    WHERE r.avg_rating > 8
    GROUP BY g.genre
    ORDER BY COUNT(g.movie_id) DESC
    LIMIT 3
)
SELECT
    n.name                AS director_name,
    COUNT(DISTINCT m.id)  AS movie_count
FROM movie m
JOIN director_mapping dm ON m.id = dm.movie_id
JOIN names            n  ON dm.name_id = n.id
JOIN genre            g  ON m.id = g.movie_id
JOIN ratings          r  ON m.id = r.movie_id
WHERE r.avg_rating > 8
  AND g.genre IN (SELECT genre FROM top_genres)
GROUP BY n.id, n.name
ORDER BY movie_count DESC
LIMIT 3;
-- Insight: James Mangold leads.


-- Q20. Top 2 actors whose movies have a median rating >= 8
SELECT
    n.name                AS actor_name,
    COUNT(DISTINCT m.id)  AS movie_count
FROM movie m
JOIN role_mapping rm ON m.id = rm.movie_id
JOIN names        n  ON rm.name_id = n.id
JOIN ratings      r  ON m.id = r.movie_id
WHERE r.median_rating >= 8
  AND rm.category = 'actor'
GROUP BY n.id, n.name
ORDER BY movie_count DESC
LIMIT 2;


-- Q21. Top 3 production houses by total votes
SELECT
    m.production_company,
    SUM(r.total_votes)                                AS vote_count,
    RANK() OVER (ORDER BY SUM(r.total_votes) DESC)    AS prod_comp_rank
FROM movie m
JOIN ratings r ON m.id = r.movie_id
WHERE m.production_company IS NOT NULL
GROUP BY m.production_company
ORDER BY vote_count DESC
LIMIT 3;
-- Insight: Marvel Studios ranks 1st.


-- Q22. Indian actors ranked by vote-weighted average rating (min. 5 Indian movies)
WITH indian_actors AS (
    SELECT
        n.name                                                       AS actor_name,
        SUM(r.total_votes)                                           AS total_votes,
        COUNT(DISTINCT m.id)                                         AS movie_count,
        ROUND(SUM(r.avg_rating * r.total_votes) / SUM(r.total_votes), 2) AS actor_avg_rating
    FROM movie m
    JOIN role_mapping rm ON m.id = rm.movie_id
    JOIN names        n  ON rm.name_id = n.id
    JOIN ratings      r  ON m.id = r.movie_id
    WHERE m.country = 'India'
      AND rm.category = 'actor'
    GROUP BY n.id, n.name
    HAVING COUNT(DISTINCT m.id) >= 5
)
SELECT
    *,
    RANK() OVER (ORDER BY actor_avg_rating DESC, total_votes DESC) AS actor_rank
FROM indian_actors
ORDER BY actor_rank;
-- Insight: Vijay Sethupathi tops the list.


-- Q23. Top 5 actresses in Hindi movies released in India (min. 3 movies)
WITH hindi_actresses AS (
    SELECT
        n.name                                                       AS actress_name,
        SUM(r.total_votes)                                           AS total_votes,
        COUNT(DISTINCT m.id)                                         AS movie_count,
        ROUND(SUM(r.avg_rating * r.total_votes) / SUM(r.total_votes), 2) AS actress_avg_rating
    FROM movie m
    JOIN role_mapping rm ON m.id = rm.movie_id
    JOIN names        n  ON rm.name_id = n.id
    JOIN ratings      r  ON m.id = r.movie_id
    WHERE m.country = 'India'
      AND m.languages LIKE '%Hindi%'
      AND rm.category = 'actress'
    GROUP BY n.id, n.name
    HAVING COUNT(DISTINCT m.id) >= 3
)
SELECT
    *,
    RANK() OVER (ORDER BY actress_avg_rating DESC, total_votes DESC) AS actress_rank
FROM hindi_actresses
ORDER BY actress_rank
LIMIT 5;
-- Insight: Taapsee Pannu tops the list with a weighted average of 7.74.


-- Q24. Classify Thriller movies by average rating
SELECT
    m.title,
    r.avg_rating,
    CASE
        WHEN r.avg_rating > 8  THEN 'Superhit'
        WHEN r.avg_rating >= 7 THEN 'Hit'
        WHEN r.avg_rating >= 5 THEN 'One-time-watch'
        ELSE 'Flop'
    END AS movie_category
FROM movie m
JOIN ratings r ON m.id = r.movie_id
JOIN genre   g ON m.id = g.movie_id
WHERE g.genre = 'Thriller'
ORDER BY r.avg_rating DESC;


/* =====================================================================
   SEGMENT 4 - ADVANCED ANALYSIS
   ===================================================================== */

-- Q25. Genre-wise running total and moving average of average movie duration
-- Moving average uses a 3-genre window (current row + 2 preceding).
WITH genre_durations AS (
    SELECT
        g.genre,
        AVG(m.duration) AS avg_duration
    FROM movie m
    JOIN genre g ON m.id = g.movie_id
    GROUP BY g.genre
)
SELECT
    genre,
    ROUND(avg_duration, 2) AS avg_duration,
    ROUND(SUM(avg_duration) OVER w_running, 2) AS running_total_duration,
    ROUND(AVG(avg_duration) OVER w_moving, 2)  AS moving_avg_duration
FROM genre_durations
WINDOW
    w_running AS (ORDER BY genre ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
    w_moving  AS (ORDER BY genre ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
ORDER BY genre;


-- Q26. Five highest-grossing movies of each year in the top 3 genres
-- Gross income is stored as text ("$ 123456"). It is converted to a number
-- before ranking; only USD-denominated values are compared so currencies
-- are not mixed.
WITH top_genres AS (
    SELECT genre
    FROM genre
    GROUP BY genre
    ORDER BY COUNT(movie_id) DESC
    LIMIT 3
),
movie_gross AS (
    SELECT
        g.genre,
        m.year,
        m.title AS movie_name,
        m.worlwide_gross_income AS worldwide_gross_income,
        CAST(TRIM(REPLACE(m.worlwide_gross_income, '$', '')) AS DECIMAL(20, 0)) AS gross_usd
    FROM movie m
    JOIN genre g ON m.id = g.movie_id
    WHERE g.genre IN (SELECT genre FROM top_genres)
      AND m.worlwide_gross_income LIKE '$%'
),
ranked_movies AS (
    SELECT
        *,
        DENSE_RANK() OVER (PARTITION BY genre, year ORDER BY gross_usd DESC) AS movie_rank
    FROM movie_gross
)
SELECT genre, year, movie_name, worldwide_gross_income, movie_rank
FROM ranked_movies
WHERE movie_rank <= 5
ORDER BY genre, year, movie_rank;


-- Q27. Top 2 production houses by number of multilingual hits (median rating >= 8)
-- A comma in the languages column means the movie is in more than one language.
WITH multilingual_hits AS (
    SELECT
        m.production_company,
        COUNT(m.id) AS movie_count
    FROM movie m
    JOIN ratings r ON m.id = r.movie_id
    WHERE POSITION(',' IN m.languages) > 0
      AND r.median_rating >= 8
      AND m.production_company IS NOT NULL
    GROUP BY m.production_company
)
SELECT *
FROM (
    SELECT
        production_company,
        movie_count,
        RANK() OVER (ORDER BY movie_count DESC) AS prod_comp_rank
    FROM multilingual_hits
) ranked
WHERE prod_comp_rank <= 2
ORDER BY prod_comp_rank;
-- Insight: Star Cinema ranks 1st, Twentieth Century Fox 2nd.


-- Q28. Top 3 actresses by number of Superhit (avg rating > 8) Drama movies
WITH drama_actresses AS (
    SELECT
        n.name                                                       AS actress_name,
        SUM(r.total_votes)                                           AS total_votes,
        COUNT(DISTINCT m.id)                                         AS movie_count,
        ROUND(SUM(r.avg_rating * r.total_votes) / SUM(r.total_votes), 2) AS actress_avg_rating
    FROM movie m
    JOIN role_mapping rm ON m.id = rm.movie_id
    JOIN names        n  ON rm.name_id = n.id
    JOIN ratings      r  ON m.id = r.movie_id
    JOIN genre        g  ON m.id = g.movie_id
    WHERE g.genre = 'Drama'
      AND r.avg_rating > 8
      AND rm.category = 'actress'
    GROUP BY n.id, n.name
)
SELECT
    *,
    ROW_NUMBER() OVER (ORDER BY movie_count DESC, actress_avg_rating DESC, total_votes DESC) AS actress_rank
FROM drama_actresses
ORDER BY actress_rank
LIMIT 3;


-- Q29. Profile of the top 9 directors by number of movies
-- LEAD() finds each director's next release date, so the gap between
-- consecutive movies can be measured in days.
WITH director_movies AS (
    SELECT
        dm.name_id AS director_id,
        n.name     AS director_name,
        m.id       AS movie_id,
        m.date_published,
        m.duration,
        r.avg_rating,
        r.total_votes,
        LEAD(m.date_published) OVER (
            PARTITION BY dm.name_id ORDER BY m.date_published
        ) AS next_movie_date
    FROM director_mapping dm
    JOIN names   n ON dm.name_id = n.id
    JOIN movie   m ON dm.movie_id = m.id
    JOIN ratings r ON m.id = r.movie_id
),
director_summary AS (
    SELECT
        director_id,
        director_name,
        COUNT(movie_id)                                             AS number_of_movies,
        ROUND(AVG(DATEDIFF(next_movie_date, date_published)))       AS avg_inter_movie_days,
        ROUND(AVG(avg_rating), 2)                                   AS avg_rating,
        SUM(total_votes)                                            AS total_votes,
        MIN(avg_rating)                                             AS min_rating,
        MAX(avg_rating)                                             AS max_rating,
        SUM(duration)                                               AS total_duration,
        ROW_NUMBER() OVER (ORDER BY COUNT(movie_id) DESC, SUM(total_votes) DESC) AS director_rank
    FROM director_movies
    GROUP BY director_id, director_name
)
SELECT
    director_id,
    director_name,
    number_of_movies,
    avg_inter_movie_days,
    avg_rating,
    total_votes,
    min_rating,
    max_rating,
    total_duration
FROM director_summary
WHERE director_rank <= 9
ORDER BY director_rank;
