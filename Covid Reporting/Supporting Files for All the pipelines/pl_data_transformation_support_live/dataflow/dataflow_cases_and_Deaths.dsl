source(output(
		country as string,
		country_code as string,
		continent as string,
		population as integer,
		indicator as string,
		daily_count as short,
		date as date,
		rate_14_day as double,
		source as string
	),
	allowSchemaDrift: true,
	validateSchema: false,
	ignoreNoFilesFound: false) ~> Casesanddeaths
source(output(
		country as string,
		country_code_2_digit as string,
		country_code_3_digit as string,
		continent as string,
		population as integer
	),
	allowSchemaDrift: true,
	validateSchema: false,
	ignoreNoFilesFound: false) ~> Countrylookup
Casesanddeaths filter(continent == 'Europe' && not(isNull(country_code))) ~> filtereuonly
filtereuonly select(mapColumn(
		country,
		country_code,
		population,
		indicator,
		daily_count,
		source,
		each(match(name=='date'),
			'reported'+'_date' = $$)
	),
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true) ~> SelectOnlyRequiredFields
SelectOnlyRequiredFields pivot(groupBy(country,
		country_code,
		population,
		source,
		reported_date),
	pivotBy(indicator, ['confirmed cases', 'deaths']),
	Count = sum(daily_count),
	columnNaming: '$V_$N',
	lateral: true) ~> pivotcounts
pivotcounts, Countrylookup lookup(pivotcounts@country == Countrylookup@country,
	multiple: false,
	pickup: 'any',
	broadcast: 'auto')~> lookupCountry
lookupCountry select(mapColumn(
		country = pivotcounts@country,
		country_code_2_digit,
		country_code_3_digit,
		population = pivotcounts@population,
		{confirmed cases_Count},
		deaths_Count,
		source,
		reported_date,
		country = Countrylookup@country
	),
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true) ~> selectforsink
selectforsink sink(allowSchemaDrift: true,
	validateSchema: false,
	truncate: true,
	umask: 0022,
	preCommands: [],
	postCommands: [],
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true) ~> CasesAndDeathsSink