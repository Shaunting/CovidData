-- Check imports
Select * 
From PortfolioProject..CovidDeaths
Order by 3,4

Select * 
From PortfolioProject..CovidVaccinations
Order by 3,4


-- Check data type
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'CovidDeaths';


-- Change data types
Alter table CovidDeaths
Alter column total_cases float;

Alter table CovidDeaths
Alter column total_deaths float;

Alter table CovidDeaths
Alter column new_cases float;

Alter table CovidDeaths
Alter column new_deaths float;

Alter table CovidVaccinations
Alter column new_vaccinations float;

-- Select columns of data we need 
Select location, date, total_cases, new_cases, total_deaths, population
From PortfolioProject..CovidDeaths
Order by 1,2

-- Total Cases vs Total Deaths
-- Percentage of deaths for covid cases
Select location, date, total_cases, total_deaths, (total_deaths / NULLIF(total_cases,0))*100 as Death_Percentage
From PortfolioProject..CovidDeaths
Where location like '%states%'
Order by 1,2


-- Total Cases vs Total Population
-- Percentage of population who contracted Covid
Select location, date, total_cases, population, (total_cases / NULLIF(population,0))*100 as Cases_Percentage
From PortfolioProject..CovidDeaths
Where location like '%states%'
Order by 1,2


-- Countries wth the highest infection rate compared to population 
Select location, MAX(total_cases) as HighestInfectionCount, Population, MAX(total_cases / NULLIF(population,0))*100 as Cases_Percentage
From PortfolioProject..CovidDeaths
Group by location, population
Order by Cases_Percentage desc
/* 
Findings:
- 20 countries had more than half of their population infected
- More than 70% of the population was infected in Cyprus and San Marino
*/

-- Large countries wth the highest infection rate compared to population 
Select location, MAX(total_cases) as HighestInfectionCount, MAX(total_deaths) as HighestDeathCount, Population, MAX(total_cases / NULLIF(population,0))*100 as Cases_Percentage, AVG(total_deaths / NULLIF(total_cases,0))*100 as Death_Percentage
From PortfolioProject..CovidDeaths
Where Population >100000000 AND continent is not NULL
Group by location, population
Order by Cases_Percentage desc
/* 
Findings:
- Some locations are listed as income level ('High income', 'Lower middle income', 'Low income', 'Upper middle income'), some as continents (Europe, Asia, etc)
- The higher the income, higher number of infections
- Looking only at large countries, the highest infection rate reduces to 30% (From 60%)
- Top 5 locations with high infection percentage (United States, Japan, Brazil, and Russia)
*/


-- Large countries wth the highest infection rate compared to population 
Select location, MAX(total_cases) as HighestInfectionCount, MAX(total_deaths) as HighestDeathCount, Population, MAX(total_cases / NULLIF(population,0))*100 as Cases_Percentage, AVG(total_deaths / NULLIF(total_cases,0))*100 as Death_Percentage
From PortfolioProject..CovidDeaths
Where date = (SELECT MAX(date) FROM PortfolioProject..CovidDeaths) -- Highest Death ratio
Group by location, population
HAVING MAX(total_cases) > 1
Order by Death_Percentage desc
/* 
Findings:
- Yemen leads with 18 deaths per infection
- Average ~1.35 deaths per infection
*/



-- Investigate the locations that aren't countries
Select SUM(MaxPopulation) as TotalPopulation
From (
	Select MAX(POPULATION) as MaxPopulation
	From PortfolioProject..CovidDeaths
	Where location in ('High income', 'Lower middle income', 'Low income', 'Upper middle income')
	Group by location
)AS MaxPopulations;
/* 
Findings:
- Income levels add up to the total population on earth 
*/


-- Countries wth the highest death counts compared to population 
Select location, MAX(total_deaths) as TotalDeathsCounts
From PortfolioProject..CovidDeaths
Where continent is not Null
Group by location
Order by TotalDeathsCounts desc
/* 
Findings:
- 20 countries had more than half of their population infected
- More than 70% of the population was infected in Cyprus and San Marino
*/


-- Analyze by continent
Select continent, MAX(total_deaths) as TotalDeathsCounts
From PortfolioProject..CovidDeaths
Where continent is not Null
Group by continent
Order by TotalDeathsCounts desc

Select location, MAX(total_deaths) as TotalDeathsCounts, Population
From PortfolioProject..CovidDeaths
Where continent is Null AND location not like '%income%'
Group by location, Population
Order by TotalDeathsCounts desc
/* 
Findings:
- Group by continents vs Group by location (where continent is not null)
- Seems like grouping by continents is gives a wrong result
- Since the numbers when death counts are lower, there seems to be some missing values in each country 
*/


----- GLOBAL NUMBERS -----

Select date, SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, ROUND(SUM(new_deaths)/SUM(new_cases)*100,3) as 'DeathPercentage (%)'
From PortfolioProject..CovidDeaths
Where continent is not null
Group by date
Order by 1


Select SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, ROUND(SUM(new_deaths)/SUM(new_cases)*100,3) as 'DeathPercentage (%)'
From PortfolioProject..CovidDeaths
Where continent is not null
Order by 1
/* 
Findings:
- 1 percent death percentage over all cases
- 6.8M deaths and 674M deaths
*/


-- Total population vs Vaccinations 
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) Over (Partition by dea.location Order by dea.location, dea.date) as RollingVaccinations -- Rolling sum 
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location And dea.date = vac.date
Where dea.continent is not null
Order by 2,3


-- CTE
With PopvsVac(Continen, Location, Date, Population, new_vaccinations, RollingPeopleVaccinated)
As (
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) Over (Partition by dea.location Order by dea.location, dea.date) as RollingVaccinations -- Rolling sum 
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location And dea.date = vac.date
Where dea.continent is not null
)
Select *, RollingPeopleVaccinated/Population*100 as VacinatedPercentage
From PopvsVac


-- Temp tables
Drop table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
Continent nvarchar (255),
Location nvarchar (255), 
Date datetime, 
Population numeric, 
New_vaccinations numeric,
RollingVaccinations numeric
)

Insert into #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) Over (Partition by dea.location Order by dea.location, dea.date) as RollingVaccinations -- Rolling sum 
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location And dea.date = vac.date
Where dea.continent is not null

Select *, (RollingVaccinations/Population)*100 as VacinatedPercentage
From #PercentPopulationVaccinated

-- do more temp tables
-- create multiple views


-- VIEWS (To store data for later visualizations)
Create View PercentPopulationVaccinated as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) Over (Partition by dea.location Order by dea.location, dea.date) as RollingVaccinations -- Rolling sum 
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location And dea.date = vac.date
Where dea.continent is not null








