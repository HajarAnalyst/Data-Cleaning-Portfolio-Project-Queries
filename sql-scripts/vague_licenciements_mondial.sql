-- Data cleaning

SELECT * 
FROM world_layoffs.layoffs;

-- staging table (de la bdd brut)
CREATE TABLE world_layoffs.layoffs_staging 
LIKE world_layoffs.layoffs;

INSERT layoffs_staging 
SELECT * FROM world_layoffs.layoffs;

-- 1. Verifier et Retirer les doublons

SELECT *
FROM world_layoffs.layoffs_staging
;

-- donner un num unique à chaque ligne
SELECT company, industry, total_laid_off,`date`,
		ROW_NUMBER() OVER (
			PARTITION BY company, industry, total_laid_off,`date`) AS row_num
	FROM 
		world_layoffs.layoffs_staging;

SELECT *
FROM (
	SELECT company, industry, total_laid_off,`date`,
		ROW_NUMBER() OVER (
			PARTITION BY company, industry, total_laid_off,`date`
			) AS row_num
	FROM 
		world_layoffs.layoffs_staging
) duplicates
WHERE 
	row_num > 1;
    
-- verification avec l'ent Oda pour voir la cohérence
SELECT *
FROM world_layoffs.layoffs_staging
WHERE company = 'Oda'
;

-- verification sur toutes les colonnes 
SELECT *
FROM (
	SELECT company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions,
		ROW_NUMBER() OVER (
			PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
	FROM 
		world_layoffs.layoffs_staging
) duplicates
WHERE 
	row_num > 1;

-- impossible de supprimer directement     
WITH DELETE_CTE AS 
(
SELECT *
FROM (
	SELECT company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions,
		ROW_NUMBER() OVER (
			PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
	FROM 
		world_layoffs.layoffs_staging
) duplicates
WHERE 
	row_num > 1
)
DELETE
FROM DELETE_CTE
;

-- creation d'une autre bdd pour la suppression 

ALTER TABLE world_layoffs.layoffs_staging ADD row_num INT;

SELECT *
FROM world_layoffs.layoffs_staging
;

CREATE TABLE `world_layoffs`.`layoffs_staging2` (
`company` text,
`location`text,
`industry`text,
`total_laid_off` INT,
`percentage_laid_off` text,
`date` text,
`stage`text,
`country` text,
`funds_raised_millions` int,
row_num INT
);

INSERT INTO `world_layoffs`.`layoffs_staging2`
(`company`,
`location`,
`industry`,
`total_laid_off`,
`percentage_laid_off`,
`date`,
`stage`,
`country`,
`funds_raised_millions`,
`row_num`)
SELECT `company`,
`location`,
`industry`,
`total_laid_off`,
`percentage_laid_off`,
`date`,
`stage`,
`country`,
`funds_raised_millions`,
		ROW_NUMBER() OVER (
			PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
	FROM 
		world_layoffs.layoffs_staging;

-- suppression des lignes en double        
DELETE FROM world_layoffs.layoffs_staging2
WHERE row_num >= 2;

SELECT *
FROM layoffs_staging2;

-- 2. Standardisation des données

SELECT * 
FROM world_layoffs.layoffs_staging2;

-- ligne NULL et vide
SELECT DISTINCT industry
FROM world_layoffs.layoffs_staging2
ORDER BY industry;

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE industry IS NULL 
OR industry = ''
ORDER BY industry;

-- verification avec bally's
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE company LIKE 'Bally%';

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE company LIKE 'airbnb%';
-- ligne vide dans industry mais même nom d'ent

-- mettre les lignes vide à NULL 
UPDATE world_layoffs.layoffs_staging2
SET industry = NULL
WHERE industry = '';

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE industry IS NULL 
OR industry = ''
ORDER BY industry;

UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE industry IS NULL 
OR industry = ''
ORDER BY industry;

-- doublon dans industry
SELECT DISTINCT industry
FROM world_layoffs.layoffs_staging2
ORDER BY industry;

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry IN ('Crypto Currency', 'CryptoCurrency');

SELECT DISTINCT industry
FROM world_layoffs.layoffs_staging2
ORDER BY industry;


SELECT *
FROM world_layoffs.layoffs_staging2;

-- standardisation de United States qui est en double avec un point en plus
SELECT DISTINCT country
FROM world_layoffs.layoffs_staging2
ORDER BY country;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country);

SELECT DISTINCT country
FROM world_layoffs.layoffs_staging2
ORDER BY country;

-- Standardisation de Date
SELECT *
FROM world_layoffs.layoffs_staging2;

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

SELECT *
FROM world_layoffs.layoffs_staging2;

-- 3. pas de changement pour les  valeurs NULL 

-- 4. drop des colonnes et lignes inutilisables

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE total_laid_off IS NULL;

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Suppression des lignes inutilisables
DELETE FROM world_layoffs.layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

SELECT * 
FROM world_layoffs.layoffs_staging2;

-- Suppression de la colonne row_num, qui n'est plus utile
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

SELECT * 
FROM world_layoffs.layoffs_staging2;





-- Exploratory Data Analysis

SELECT * 
FROM world_layoffs.layoffs_staging2;

SELECT MAX(total_laid_off)
FROM world_layoffs.layoffs_staging2;

-- Pourcentage max et min du laid off, 1 = 100% : faillite de l'ent
SELECT MAX(percentage_laid_off),  MIN(percentage_laid_off)
FROM world_layoffs.layoffs_staging2
WHERE  percentage_laid_off IS NOT NULL;

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE  percentage_laid_off = 1;
-- 116 d'ent en faillite (majoritairement des startups)

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE  percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;
-- Parmi celles-ci, certaines ont réalisé de grandes levées de fonds 

-- Top 5 des ent ayant réalisé les plus gros licenciements en une seule journée (en une seul fois)
SELECT company, total_laid_off
FROM world_layoffs.layoffs_staging
ORDER BY 2 DESC
LIMIT 5;

-- Top des ent ayant effectué le plus grd nb de licenciements au total 
SELECT company, SUM(total_laid_off)
FROM world_layoffs.layoffs_staging2
GROUP BY company
ORDER BY 2 DESC
LIMIT 10;

-- Par lieu
SELECT location, SUM(total_laid_off)
FROM world_layoffs.layoffs_staging2
GROUP BY location
ORDER BY 2 DESC
LIMIT 10;

-- Total par pays 

SELECT country, SUM(total_laid_off)
FROM world_layoffs.layoffs_staging2
GROUP BY country
ORDER BY 2 DESC;

-- Total par année
SELECT YEAR(date), SUM(total_laid_off)
FROM world_layoffs.layoffs_staging2
GROUP BY YEAR(date)
ORDER BY 1 ASC;

-- Total par secteur
SELECT industry, SUM(total_laid_off)
FROM world_layoffs.layoffs_staging2
GROUP BY industry
ORDER BY 2 DESC;

-- Total par phase de financement
SELECT stage, SUM(total_laid_off)
FROM world_layoffs.layoffs_staging2
GROUP BY stage
ORDER BY 2 DESC;

-- Top 3 des ent avec le plus de licenciements par année
WITH Company_Year AS 
(
  SELECT company, YEAR(date) AS years, SUM(total_laid_off) AS total_laid_off
  FROM layoffs_staging2
  GROUP BY company, YEAR(date)
)
, Company_Year_Rank AS (
  SELECT company, years, total_laid_off, DENSE_RANK() OVER (PARTITION BY years ORDER BY total_laid_off DESC) AS ranking
  FROM Company_Year
)
SELECT company, years, total_laid_off, ranking
FROM Company_Year_Rank
WHERE ranking <= 3
AND years IS NOT NULL
ORDER BY years ASC, total_laid_off DESC;


-- Total cumulé des licenciements par mois
SELECT SUBSTRING(date,1,7) as dates, SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
WHERE SUBSTRING(date,1,7) IS NOT NULL
GROUP BY dates
ORDER BY dates ASC;

WITH DATE_CTE AS 
(
SELECT SUBSTRING(date,1,7) as dates, SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
WHERE SUBSTRING(date,1,7) IS NOT NULL
GROUP BY dates
ORDER BY dates ASC
)
SELECT dates, total_laid_off , SUM(total_laid_off) OVER (ORDER BY dates ASC) as rolling_total_layoffs
FROM DATE_CTE
ORDER BY dates ASC;
