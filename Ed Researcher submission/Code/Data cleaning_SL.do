/*************************************************
* Purpose: Cleaning merged NYC pre-k data files
* Author: Scott Latham
*
* Creates the following datasets:
*	1. Provider-level
*	2. Tract-level (merged w/provider data)
*	4. Borough-level
*	3. Mapping data 	
*
* Date created: 10/29/2018
* Last updated: 10/21/2019
*****************************************************/
	
//Cleaning merged file
***********************
	use "${inter}/NYC merged provider-level pre-k", clear

	# delimit ;
	
		drop   
		
		/* Irrelevant for this work */
			email phone* website* nta* contact_name contact_email x y_loc community* 
			subway_stop bus council* bbl* dailystarttime
			
		/* Duplicate information */
			dbn* class*rating ecers*rating 
			
		/* Not enough info to be useful */  
		   qualityreview* extended_day singlegender flexschedule lpga halfday_offers rezoning iepnote
		   specialpriority magnet diversity  
		   collaborativeteachers-surveyguardianresponse
		;		
		
	# delimit cr	

	
	//Combining variables across datasets
		cap program drop combine
		program combine
			args newvar varlab type var1 var2 var3 var4 var5
			
			cap drop `newvar'
			gen `newvar' = `var1'
			label var `newvar' "`varlab'"
			
			forvalues i = 2/5	{
				if "`type'" == "string"		cap replace `newvar' = `var`i'' if `newvar'==""
				if "`type'" == "int" 		cap replace `newvar' = `var`i'' if `newvar'==.
			}
			
			forvalues i = 1/5	{
				cap drop `var`i''
			}
			
		end //ends program combine
		
		/*I've made the decision to privilege data in the following order:
			1. Directory, 2. Quality, 3. Demographics, 4. Locations, 5. Inspections
			I made this decision because the directory/quality demographics data are almost always in agreement, while the locations file frequently differs
			for some of the pre-k characteristics variables (e.g., full vs. half, seats, meals, playspace). I wanted to make sure I was getting the best 
			consistency possible, so I only rely on locations data if the other 3 are missing.
		*/
		
		combine name 			"Program name"			string  name_dir 		name_qual	 		name_dem 			name_loc	name_ins	
		*0 missing
		
		combine prek_type_raw	"Pre-k type"			string	prek_type_dir	prek_type_qual 		prek_type_dem   	prek_type_loc	prek_type_ins 
		*0 missing
		
		combine boro			"Borough"				string  borough_dir		borough_qual		borough_dem			borough_loc		borough_ins 
		*1 missing (fixed below)
	
		combine zip				"ZIP code"				int		postcode_dir	postcode_qual  		postcode_dem		postcode_loc		postcode_ins
		*1 missing
		
		combine address			"Street address"		string  address_dir 	address_qual		address_loc			address_ins
		*16 missing (from dem file, didn't add in from RANYCS, but could)

		combine tract 			"Census tract"			string	tract_dir		tract_loc			tract_ins										
		combine latitude		"Latitude"				int		latitude_dir	latitude_loc		latitude_ins
		combine longitude		"Longitude"				int		longitude_dir	longitude_loc		longitude_ins
		*55 missing, 54 are only in qual or dems file, which don't have tract info, 1 is in directory file but missing tract
		
		combine district		"School district"		int		district_dir	district_qual		district_loc
		*1367 missing, all providers only in inspections data + 18 only in dem file (can fix this by merging zips)
		
		combine	bin				"Building ID number"	int		bin_dir			bin_loc			
		*1440 missing, including 106 UPK providers
	
		combine late_pickup 	"Late pickup"			int		late_pickup_dir	late_pickup_qual
		combine early_drop		"Early dropoff"			int		early_drop_dir	early_drop_qual
		*1585 missing, including 251 UPK providers
		
		combine dual_lang		"Dual language"				int		dual_lang_dir		dual_lang_qual
		combine dual_lang_span	"Dual language: Spanish"	int		dual_lang_span_dir	dual_lang_span_qual
		*1397 missing, including 56 UPK providers
		
		//Variables that differ between loc & dir files
		***********************************************************************************************************
			combine seats			"# of seats"								int		seats_dir		seats_loc
			combine income_req 		"Income req. for at least some students"	int		income_flg_dir 	income_flg_loc
			*1414 missing, including 80 UPK providers (those unique to quality/dem/inspections files)
			
			combine full_day		"Full day program"							int		full_day_dem	full_day_dir	full_day_qual	full_day_loc	
			combine half_day		"Half day program"							int		half_day_dem	half_day_dir	half_day_qual 	half_day_loc	
			*1410 missing, including 76 UPK providers (those unique to dem/inspections files & those w/missing data in qual file)		
			
			combine meals			"# of meals/day"		int		meals_dir		meals_qual		meals_loc		
			*1620 missing, including 286 UPK providers, all private providers
			
			combine indoor			"Indoor play space"		int		indoor_dir		indoor_qual		indoor_loc		
			combine outdoor			"Outdoor play space"	int		outdoor_dir 	outdoor_qual	outdoor_loc		
			*1737 missing, including 403 UPK providers
					

				
	//Cleaning combined data
	*****************************
		
	//Provider location
		label var siteid "Program ID (last 4 digits of dbn or day care id)"
		
		*Borough - Refers to "boro" variable created above	
			replace boro = "Brooklyn" if boro=="" //One missing observation: "Mosaic pre-k center", looked it up in Google
			encode boro, gen(borough)
			
			label define boro 1 "Bronx" 2 "Brooklyn" 3 "Manhattan" 4 "Queens" 5 "Staten Island"
			label values borough boro
			
			tab borough, gen(B)
			rename (B1 B2 B3 B4 B5) (bronx brooklyn manhattan queens staten)
			
		*Census tracts - Refers to "tract" variable created above
			*In directory, locations, & inspections data, tracts are coded without leading & sometimes w/o trailing 0s.
			* Can't merge with ACS data this way. I've been able to restore leading and trailing zeroes with really good (albeit imperfect)
			* fidelity via the method below. I compared the zero-less tracts to ACS tracts and in nearly all cases there was only one
			* possible match. Biggest issue is I wasn't able to do this for single digit tracts.
			
			destring tract, ignore(",") replace
			tostring tract, replace //removing commas
		
			gen trlen = length(tract)
			gen last2 = substr(tract,-2,.)
			gen ending = last2=="00" | last2 == "01" | last2 == "02"
		
			sort trlen tract
			
			gen tractnum = tract if trlen==6
			replace tractnum = "0" + tract if trlen==5
			replace tractnum = tract + "00" if trlen==4 & ending==0
			
			replace tractnum = "00" + tract if trlen==4 & ending==1 
			//This step isn't perfect b/c some truncated tracts could potentially match to multiple ACS tracts, but damn close
			
			replace tractnum = "0" + tract + "00" if trlen==3
			replace tractnum = "00" + tract + "00" if trlen==2
			
			replace tractnum = "000" + tract + "00" if trlen==1 & tract != "."
			//Single digits could all potentially map to multiple tracts, but given the patterns above
			// this seems like the most likely scenario. Luckily only 16 obs.
			
			//Leaves 56 providers (all UPK) without tract IDs		
			replace tractnum = "999999" if tractnum==""
			*Fill in missing tract data w/missing indicators
			
			label var tractnum "Tract ID number"	
			drop tract trlen last2 ending 
			
	//Program characteristics
			
		*Pre-k type (DOE, NYCEEC, charter, private) - Refers to "prek_type_raw" variable created above
			gen prek_type = .
			label var prek_type "Type of pre-k"
			
			replace prek_type = 1 if prek_type_raw == "DOE" | prek_type_raw=="District School"
			replace prek_type = 2 if prek_type_raw == "Pre-K Center"
			replace prek_type = 3 if prek_type_raw == "NYCEEC" 
			replace prek_type = 4 if prek_type_raw == "Charter School" 
			replace prek_type = 5 if prek_type_raw == "Special ed"
			replace prek_type = 6 if prek_type_raw == "Private" //Everyone in inspections data not classified as UPK			
			
			label define pktyp 1 "DOE K-12" 2 "DOE Pre-k center" 3 "NYCEEC" 4 "Charter" 5 "Special ed" 6 "Private provider"
			label values prek_type pktyp
				drop prek_type_raw
				 
			gen prek_3type = 1 	   if prek_type==1 | prek_type==2 | prek_type==5
			replace prek_3type = 2 if prek_type==3
			replace prek_3type = 3 if prek_type==6
			
			label define pk3typ 1 "DOE (K-12/Pre-k/Special ed)" 2 "NYCEEC" 3 "Private"
			label values prek_3type pk3typ
			
			
			//Indicators for all the pre-k types
				gen DOE_k12 = prek_type==1
				label var DOE_k12 "DOE-run program in K12 school"
				
				gen DOE_pk = prek_type==2
				label var DOE_pk "DOE-run independent pre-k center"
				
				gen DOE = DOE_k12==1 | DOE_pk==1
				label var DOE "DOE K12 or pre-k center"
				
				gen NYCEEC = prek_type==3
				label var NYCEEC "NYC early education center"			
				
				gen charter = prek_type==4
				label var charter "UPK in charter school"
				
				gen special_ed = prek_type==5
				label var special_ed "Special ed. program"
				
				gen private = prek_type==6 
				label var private "Private provider"


		*Special program types (montessori, spanish/chinese, religious)
			gen nlow = lower(name)
				
			gen mont= strpos(nlow, "montessori") > 0
			label var mont "Montessori School"

			# delimit ;

			loc spanish "trabajamos nuevo mundo abierta dominican ninos nuestros escuela hispana pequenos escuelita casita"	;

			loc chinese "chinese kon xing dragon chinatown khwoa chung kuei chang sheng"	;

			loc christian 
				"church catholic virgin conception parochial god christ saint jesus ourlady methodist 
				sacred tolentine lutheran bishop monsignor blessed holy notre ascension baptist 
				nazareth atonement noah episcopal immanuel incarnation" ;
				
			loc jewish 
				"temple yeled jewish bnos yeshiva sholom hagolah hebrew torah talmud chabad neshama 
				yaffa gan bais baais beth ohr zion mazel chaya rabbi sephardic tomer mevakshei cheder 
				shalva keshet judea 
				ezer shlomo moshe yaakov congregation dvora ktantanim machzik mosdoth renanim akiba
				shalom shemtov shira synagogue yaldaynu kodesh aleph" ; 
				
			loc muslim "ihsan mamoor madinah iman noor islamic" ;

			# delimit cr

			foreach x in spanish chinese christian jewish muslim	{
				gen `x' = 0 //No missing data, all providers have names
				
				foreach i in ``x''	{
					replace `x' = 1 if strpos(nlow, "`i'") > 0 
				}
			}

			label var spanish 	"Spanish provider"
			label var chinese 	"Chinese provider"
			label var christian "Christian provider"
			label var jewish 	"Jewish provider"
			label var muslim 	"Muslim provider"
			
			//Fixing some errors that weren't easily automated
				replace christian = 1 if strpos(nlow, "st.") >0
				replace christian = 1 if strpos(nlow, "our lady") >0
				replace christian = 0 if strpos(nlow, "goddard") >0
				
				replace christian = 1 if name=="Guardian Angel" //Looked this one up on Google
				
				replace jewish = 0 if christian==1 
				//5 observations that were marked as both, all were Christian
				
				# delimit ;
				loc nonrel `"
					"Christopher Avenue Community School"			"BRIGHT HORIZONS AT 96TH ST."
					"Strong Place For Hope DCC - Clinton St."		"Grand St. Settlement Dual Center #1"					
					"Virginia Day Nursery"							"Grand St. Settlement Head Start Center"
					"Grand St. Settlement"							"F.V.M. BETHEL DAY CARE (P.S.)"
					"Salvation Army New York TempleCorp"			"The Salvation Army Harlem Temple Community Center"				
					"All Children's Child Care ( 24th St. )"		"BETHANY DAY NURSERY  INC."
					"Brite Adventure Center ( 30th St. )"			"Brite Adventure Center ( 58th St. )"
					"Apple Tree DCC ( 197th St. )"					"Bronx Charter School For Better Learning"				
					"Pre - K Center At 2 - 26 Washington St."		"J.P. MORGAN CHASE BACK UP CHILD CARE CENTER"
					"Mary Mcleod Bethune Child Development Center"	"CHURCH STREET SCHOOL FOR MUSIC AND ART  INC." 				
					"Joan Ganz Cooney Early Learning Program"		"LITTLE RED SCHOOL HOUSE & ELIZABETH IRWIN HIGH SCHOOL"
					"Aleene Logan Day Care"							"BRONX ORGANIZATION FOR THE LEARNING DISABLED OF NEW YORK"	
					"MARY MCLEOD BETHUNE DAY CARE CENTER INC."		"COUNCIL OF PEOPLES ORGANIZATION INC"							
					"' ;		
				# delimit cr
				
				foreach type in christian jewish muslim {
					replace `type'=0 if DOE==1 | special_ed==1
					
					foreach provname in `nonrel'	{
						replace `type' = 0 if name=="`provname'"
					}			
				}
				
			gen relig = christian==1 | jewish==1 | muslim==1
			label var relig "Religious-sponsored provider"
			
			//"ST. JOSEPH'S SCHOOL FOR THE DEAF"?
			//LSSMNY: stands for Lutheran Social Services of Metropolitan NY, but they don't seem to have a religious component
		
			drop nlow
		
		//Dual language
			//rename from directory file, because I chose to only use those data
			foreach x in enh_lang enh_lang_span enh_lang_chin enh_lang_jewish	{
				rename `x'_dir `x'
			}
			

	//Provider quality 

		*CLASS
			rename classmostrecent CLASS_year
			label var CLASS_year "Most recent assessment year"
			
			rename classemotionalsupport 		CLASS_E
			rename classclassroomorganization 	CLASS_O
			rename classinstructionalsupport	CLASS_I
			
			egen CLASS_avg = rowmean(CLASS_E CLASS_O CLASS_I)
			label var CLASS_avg "Average CLASS score"
			
			order CLASS_avg, before(CLASS_E)
			
			gen CLASS_E_HI = CLASS_E >=5 if CLASS_E !=.
			label var CLASS_E_HI "CLASS emotional support score >= 5.0"
			
			gen CLASS_O_HI = CLASS_O >=5 if CLASS_O !=.
			label var CLASS_O_HI "CLASS classroom organization score >= 5.0"
			
			gen CLASS_I_HI = CLASS_I >=3 if CLASS_I !=.
			label var CLASS_I_HI "CLASS instructional support score >=3.0"
			
			egen CLASS_quint = cut(CLASS_avg), group(5)
			
		*ECERS
			rename ecersmostrecent ECERS_year
			label var ECERS_year "Most recent assessment year"
			
			# delimit ;
			rename (ecersobservationaverage ecerslangua ecersinteract ecersactivities 
					ecerspersonal ecersspaceandfu ecersprogram) 
					
					(ECERS_avg ECERS_language ECERS_interact ECERS_activities 
					ECERS_pcare ECERS_space ECERS_structure ) ;
			# delimit cr		
			
			gen ECERS_HI = ECERS_avg >=4.5 if ECERS_avg !=.
			label var ECERS_HI "ECERS score >=4.5"
			
			gen ECERS_LO = ECERS_avg <4 if ECERS_avg !=.
			label var ECERS_LO "ECERS score < 4.0"
		
			egen ECERS_quint = cut(ECERS_avg), group(5)
			label var ECERS_quint "ECERS quintiles (0-4)"
			
		*Standardizing quality measures
			foreach x of varlist CLASS_avg-CLASS_I ECERS_avg-ECERS_structure	{
				egen `x'_z = std(`x')
			}
		
		*Other program characteristics	
			//Taking these out for now, need to give them another look
			drop nyceec* district_* pkc*
			
			/*
		//Imputing some plausible CLASS values
			sum CLASS_avg
			loc m=r(mean)
			loc sd=r(sd)
			
			gen CLASS_low = CLASS_avg
			gen CLASS_med = CLASS_avg
			gen CLASS_hi = CLASS_avg
			
			replace CLASS_low = rnormal(`m'-(.5*`sd'), `sd') if CLASS_missing==1
			replace CLASS_med = rnormal(`m', `sd') 			 if CLASS_missing==1
			replace CLASS_hi  = rnormal(`m'+(.5*`sd'), `sd') if CLASS_missing==1

			*/
			//Missingness indicators
			gen CLASS_missing = CLASS_avg ==. if private!=1
			gen ECERS_missing = ECERS_avg ==. if private!=1
			
			gen playspace_missing = indoor==. if private!=1
			
		/*
		
			
		//NYCEEC- & DOE-specific chars	
			tostring nyceec_current_none, replace
					
			foreach x in current siblings services targetlang others	{
				gen nyceec_`x' = -9
				replace	nyceec_`x' = 1 if nyceec_`x'_all  == "x" | nyceec_`x'_some == "x"
				replace nyceec_`x' = 0 if nyceec_`x'_none == "x"
				replace nyceec_`x' = . if NYCEEC==0
				
				drop nyceec_`x'_all nyceec_`x'_some nyceec_`x'_none
			}
			
			label var nyceec_current 	"Current students received offers last year"
			label var nyceec_siblings 	"Siblings received offers last year"
			label var nyceec_services	"Students receiving social services received offers last year"
			label var nyceec_targetlang	"Enhanced lang programs: Students that speak target language received offers last year"
			label var nyceec_others		"Other students received offers last year"
			
			
			tostring district_zonedsib_none, replace
			
			foreach x in zonedsib otherzone districtsibs outdissibs indistrict outdistrict	{
				gen district_`x' = -9
				replace	district_`x' = 1 if district_`x'_all  == "x" | district_`x'_some == "x"
				replace district_`x' = 0 if district_`x'_none == "x"
				replace district_`x' = . if DOE==0
				
				drop district_`x'_all district_`x'_some district_`x'_none
			}
			
			label var district_zonedsib		"Zoned siblings received offers last year"
			label var district_otherzone	"Other zoned students received offers last year"
			label var district_districtsibs	"In-district siblings received offers last year"
			label var district_outdissibs	"Out-of-district siblings received offers last year"
			label var district_indistrict	"In-district students received offers last year"
			label var district_outdistrict	"Out-of-district students received offers last year"
			
		
		//For now, drop pkc variables (seem to be related to district vars)
			//drop pkc*
			tostring pkc_indistrict_none_dir, replace
			replace pkc_indistrict_none_dir = "" if pkc_indistrict_none_dir=="."			
			
			gen pkc = pkc_indistrict_all_dir != ""
			replace pkc =1 if pkc_indistrict_some_dir != ""
			replace pkc =1 if pkc_indistrict_none_dir != ""
			label var pkc "Independent pre-k center"
			
			drop pkc_*
			
		label define all_or_none  0 "none" 1 "all/some"
		label values nyceec_* district_* all_or_none
		
		recode nyceec_* district_* (-9=.a)
		*/
	
		
	//Enrollment & demographics		
		foreach year in 2015 2016 2017	{
			loc yplus = `year' + 1
			
			label var enrollment_`year' "Total enrollment for `year'/`yplus' school year"
			
			foreach subgrp in  female male white black hisp asian other  {
				label var num_`subgrp'_`year' "# of `subgrp' students in `year'/`yplus' school year"
				
				rename pct_`subgrp'_`year' pr_`subgrp'_`year'
				label var pr_`subgrp'_`year' "proportion of `subgrp' students in `year'/`yplus' school year"
				
				gen pct_`subgrp'_`year' = pr_`subgrp'_`year' * 100
				label var pct_`subgrp'_`year' "Percent `subgrp' in `year'/`yplus' school year (UPK only)"
			}
		}
		

	//Racially homogenous schools
		forvalues i = 2015/2017	{			
			egen max_race_`i' = rowmax(pct_white_`i' pct_black_`i' pct_hisp_`i' pct_asian_`i' pct_other_`i') 
			gen fairly_homog_`i' = max_race_`i' > 70 if max_race_`i' !=.
			gen highly_homog_`i' = max_race_`i' > 90 if max_race_`i' !=.
			
			label var max_race_`i' "Highest percentage of single race/ethnicity in provider (`i')"
			label var fairly_homog_`i' "Program enrolled > 70% students of a single race/ethnicity (`i')"
			label var highly_homog_`i' "Program enrolled > 90% students of a single race/ethnicity (`i')"
		}
	
	//Closure - "defined as enrollment in 2015, no enrollment in 2017"
		gen closed = 0 if enrollment_2015 !=.
		replace closed = 1 if closed ==0 & enrollment_2017 ==.
		label var closed "Program reported enrollment in 2015, not in 2017"
		
	//Define samples		
		gen samp_all = 1
		label var samp_all "All providers in dataset"
		
		gen samp_enroll = enrollment_2015 !=. | enrollment_2016 !=. | enrollment_2017 !=.
		label var samp_enroll "Providers that reported enrollment in any year 2015-2017"
		
		
			
		forvalues i = 2015/2017	{
			gen samp_`i' = enrollment_`i' !=. //UPK data
			replace samp_`i' = 1 if cyear_`i' ==1 & UPK==0 //Inspections data (using calendar year)
			
			label var samp_`i' "Providers that reported enrollment in `i'"
		}
		//drop syear* cyear*

		gen samp_qual = samp_2017==1 & ECERS_avg !=. & CLASS_avg!=.
		label var samp_qual "Providers in the 2017 sample with both ECERS/CLASS scores"
		
		gen flag_new = samp_2017==1 & UPK==1 & enrollment_2017==.

	//Order variables
		order siteid name address latitude longitude zip tract borough bronx-staten district 	///
			prek_type UPK DOE DOE_pk DOE_k12 NYCEEC charter special_ed private 					///
			full_day half_day meals indoor outdoor early_drop late_pickup hours_flg 			///
			dual_lang* enh_lang* mont spanish chinese relig christian jewish muslim 			///
			CLASS* ECERS* seats *_2015 *_2016 *_2017 closed 
			
		order samp_all-samp_qual samp_2015 samp_2016 samp_2017 flag*, last			
		
	save "${anlys}/provider-level_SL", replace
	saveold "${anlys}/provider-level_SL (12)", version(12) replace
	
 
 

 ***********************************************
 * Constructing census-tract level data
 ***********************************************
	//Reshape provider-level data to single observation (need to do this in 2 parts)
		loc reshape_vars "latitude longitude DOE NYCEEC queens enrollment_2017 ECERS_avg CLASS_avg UPK income_req samp_qual" //Add vars here that I want to aggregate to census-tract level
	
		//Need to break this into 2 parts or Stata glitches out
			foreach i in 1 2	{
			
				if `i'==1	loc obs "prov_id < 1500"
				if `i'==2	loc obs "prov_id >=1500"
				
				clear all				
				use "${anlys}/provider-level_SL", clear	
		
				gen id = 1 //Used to reshape
			
				keep if samp_2017 ==1 & latitude!=.
				
				count
				gl num_provs = r(N)
				
				gen prov_id = _n
				keep if `obs'

				keep prov_id id `reshape_vars'
			
				foreach x of varlist `reshape_vars'	{
					rename `x' `x'_
				}
				
				reshape wide `reshape_vars', i(id) j(prov_id)
				
				save "${inter}/Clean provider-level data (wide - p`i')", replace
				
			} // close i loop
			
		*Merge together
			use "${inter}/Clean provider-level data (wide - p1)", replace
			merge 1:1 id using "${inter}/Clean provider-level data (wide - p2)"
			
			save "${inter}/Clean provider-level data (wide)", replace
		
		
	
	//Merge census tract data w/provider info, calculate distances between each pair
	*********************************************************************************
		clear all
		set maxvar 120000	
		
		//Calculate # of provs in sample
			use "${anlys}/provider-level_SL", clear	
			keep if samp_2017 ==1 & latitude!=.
					
			count
			gl num_provs = r(N)				
					
			use "${inter}/Clean tract-level data", clear	
			merge m:1 id using "${inter}/Clean provider-level data (wide)", nogen

		//Calculate the distance between each tract and each provider
			forvalues i = 1/$num_provs	{
				geodist intptlat intptlon latitude_`i' longitude_`i', gen(dist_`i') miles
			}

		//Generate indicators for whether each provider is within a certain distance of each tract
			forvalues i = 1/$num_provs	{
				gen within_p25_`i' = dist_`i' <=.25
				gen within_p5_`i' = dist_`i' <=.5
			}
		
		save "${inter}/Merged tract & provider data", replace	


	//Construct aggregate measures of pre-k availability
	**********************************************************
	
		//Have to generate this macro before the code below will work
			clear all
			set maxvar 120000	
			
			use "${anlys}/provider-level_SL", clear	
			keep if samp_2017 ==1 & latitude!=.
					
			count
			gl num_provs = r(N)	
		
	
		//Count the number of nearby providers based on a number of criteria
		use "${inter}/Merged tract & provider data", clear
		
		cap program drop prox
		program define prox
			args newvar expression xtracond label
			
			
			foreach dist in p25 p5 	{
			
				//Generate an indicator for each provider based on the specified criteria
				forvalues prov = 1/${num_provs}	{
					gen `newvar'_`dist'_`prov' = `expression'	if within_`dist'_`prov'==1  `xtracond'
				}
				
				//Sum across the indicators created above, then delete to avoid too many variables
				egen num_`newvar'_`dist' = rowtotal(`newvar'_`dist'_*)
				label var num_`newvar'_`dist' "`label'"
					drop `newvar'_`dist'_*
				
				//Generate a per capita measure of the specified provider type (based on the number of 4 year olds)
				gen num_`newvar'_`dist'_p = num_`newvar'_`dist' / fours_total
				label var num_`newvar'_`dist'_p "`label' (per 4 y/o)"
				
				//Generate an indicator for ANY of the specified provider types within the specified distance
				gen any_`newvar'_`dist' = num_`newvar'_`dist' !=0
				label var any_`newvar'_`dist' "Any `label'"
				
			} //close dist loop
			
		end //Ends program prox
		
		prox provs			"latitude_\`prov' !=." 	""														"Providers within \`dist' miles"
				
		
		prox UPK			"latitude_\`prov' !=." 	"& UPK_\`prov'==1"										"UPK providers within \`dist' miles"
		prox priv_provs		"latitude_\`prov' !=." 	"& UPK_\`prov'==0"										"Non-UPK providers within \`dist' miles"
		
		prox HIECERS50_UPK	"latitude_\`prov' !=." 	"& ECERS_avg_\`prov' >= 4.2 & ECERS_avg_\`prov' <." 	"Providers within \`dist' miles with ECERS >=50th pctile"
		prox HIECERS75_UPK	"latitude_\`prov' !=." 	"& ECERS_avg_\`prov' >= 4.7 & ECERS_avg_\`prov' <." 	"Providers within \`dist' miles with ECERS >=75th pctile"		
		prox HIECERS90_UPK	"latitude_\`prov' !=." 	"& ECERS_avg_\`prov' >= 5.1 & ECERS_avg_\`prov' <." 	"Providers within \`dist' miles with ECERS >=95th pctile"
	
		prox HICLASS50_UPK 	"latitude_\`prov' !=." 	"& CLASS_avg_\`prov' >= 5.3   & CLASS_avg_\`prov' <." 	"Providers within \`dist' miles with CLASS >=75th pctile"
		prox HICLASS75_UPK  "latitude_\`prov' !=." 	"& CLASS_avg_\`prov' >= 5.6   & CLASS_avg_\`prov' <." 	"Providers within \`dist' miles with CLASS >=75th pctile"
		prox HICLASS90_UPK  "latitude_\`prov' !=." 	"& CLASS_avg_\`prov' >= 5.867 & CLASS_avg_\`prov' <." 	"Providers within \`dist' miles with CLASS >=75th pctile"
		
		prox HIQONLY50_UPK	"latitude_\`prov' !=." 	"& ECERS_avg_\`prov' >= 4.2 & ECERS_avg_\`prov' <. & queens_\`prov' !=0 " 	"Providers within \`dist' miles with ECERS >=50th pctile"
		prox HIQONLY75_UPK	"latitude_\`prov' !=." 	"& ECERS_avg_\`prov' >= 4.7 & ECERS_avg_\`prov' <. & queens_\`prov' !=0 " 	"Providers within \`dist' miles with ECERS >=75th pctile"		
		prox HIQONLY90_UPK	"latitude_\`prov' !=." 	"& ECERS_avg_\`prov' >= 5.1 & ECERS_avg_\`prov' <. & queens_\`prov' !=0 " 	"Providers within \`dist' miles with ECERS >=95th pctile"
		
		/* same sample
		prox HIECERS50_UPK_2	"latitude_\`prov' !=." 	"& samp_qual_\`prov'==1 & ECERS_avg_\`prov' >= 4.2 & ECERS_avg_\`prov' <." 	"Providers within \`dist' miles with ECERS >=50th pctile"
		prox HIECERS75_UPK_2	"latitude_\`prov' !=." 	"& samp_qual_\`prov'==1 & ECERS_avg_\`prov' >= 4.7 & ECERS_avg_\`prov' <." 	"Providers within \`dist' miles with ECERS >=75th pctile"		
		prox HIECERS90_UPK_2	"latitude_\`prov' !=." 	"& samp_qual_\`prov'==1 & ECERS_avg_\`prov' >= 5.2 & ECERS_avg_\`prov' <." 	"Providers within \`dist' miles with ECERS >=95th pctile"
	
		prox HICLASS50_UPK_2 	"latitude_\`prov' !=." 	"& samp_qual_\`prov'==1 & CLASS_avg_\`prov' >= 5.3   & CLASS_avg_\`prov' <." 	"Providers within \`dist' miles with CLASS >=75th pctile"
		prox HICLASS75_UPK_2  "latitude_\`prov' !=." 	"& samp_qual_\`prov'==1 & CLASS_avg_\`prov' >= 5.6   & CLASS_avg_\`prov' <." 	"Providers within \`dist' miles with CLASS >=75th pctile"
		prox HICLASS90_UPK_2  "latitude_\`prov' !=." 	"& samp_qual_\`prov'==1 & CLASS_avg_\`prov' >= 5.867 & CLASS_avg_\`prov' <." 	"Providers within \`dist' miles with CLASS >=75th pctile"
		
		//Subscales
		prox HILANG50_UPK	"latitude_\`prov' !=." 	"& ECERS_language_\`prov' >= 5.3 & ECERS_language_\`prov' <." 	"Providers within \`dist' miles with ECERS >=50th pctile"
		prox HILANG75_UPK	"latitude_\`prov' !=." 	"& ECERS_language_\`prov' >= 6.0 & ECERS_language_\`prov' <." 	"Providers within \`dist' miles with ECERS >=75th pctile"		
		prox HILANG90_UPK	"latitude_\`prov' !=." 	"& ECERS_language_\`prov' >= 6.3 & ECERS_language_\`prov' <." 	"Providers within \`dist' miles with ECERS >=95th pctile"
		
		prox HIINTER50_UPK	"latitude_\`prov' !=." 	"& ECERS_interact_\`prov' >= 5.4 & ECERS_interact_\`prov' <." 	"Providers within \`dist' miles with ECERS >=50th pctile"
		prox HIINTER75_UPK	"latitude_\`prov' !=." 	"& ECERS_interact_\`prov' >= 6.2 & ECERS_interact_\`prov' <." 	"Providers within \`dist' miles with ECERS >=75th pctile"		
		prox HIINTER90_UPK	"latitude_\`prov' !=." 	"& ECERS_interact_\`prov' >= 6.6 & ECERS_interact_\`prov' <." 	"Providers within \`dist' miles with ECERS >=95th pctile"
		
		prox HIACTIV50_UPK	"latitude_\`prov' !=." 	"& ECERS_activities_\`prov' >= 4.5 & ECERS_activities_\`prov' <." 	"Providers within \`dist' miles with ECERS >=50th pctile"
		prox HIACTIV75_UPK	"latitude_\`prov' !=." 	"& ECERS_activities_\`prov' >= 5.3 & ECERS_activities_\`prov' <." 	"Providers within \`dist' miles with ECERS >=75th pctile"		
		prox HIACTIV90_UPK	"latitude_\`prov' !=." 	"& ECERS_activities_\`prov' >= 5.9 & ECERS_activities_\`prov' <." 	"Providers within \`dist' miles with ECERS >=95th pctile"
		
		prox HIPCARE50_UPK	"latitude_\`prov' !=." 	"& ECERS_pcare_\`prov' >= 2.7 & ECERS_pcare_\`prov' <." 	"Providers within \`dist' miles with ECERS >=50th pctile"
		prox HIPCARE75_UPK	"latitude_\`prov' !=." 	"& ECERS_pcare_\`prov' >= 3.2 & ECERS_pcare_\`prov' <." 	"Providers within \`dist' miles with ECERS >=75th pctile"		
		prox HIPCARE90_UPK	"latitude_\`prov' !=." 	"& ECERS_pcare_\`prov' >= 3.7 & ECERS_pcare_\`prov' <." 	"Providers within \`dist' miles with ECERS >=95th pctile"
		
		prox HISPACE50_UPK	"latitude_\`prov' !=." 	"& ECERS_space_\`prov' >= 3.9 & ECERS_space_\`prov' <." 	"Providers within \`dist' miles with ECERS >=50th pctile"
		prox HISPACE75_UPK	"latitude_\`prov' !=." 	"& ECERS_space_\`prov' >= 4.4 & ECERS_space_\`prov' <." 	"Providers within \`dist' miles with ECERS >=75th pctile"		
		prox HISPACE90_UPK	"latitude_\`prov' !=." 	"& ECERS_space_\`prov' >= 4.9 & ECERS_space_\`prov' <." 	"Providers within \`dist' miles with ECERS >=95th pctile"
		
		prox HISTRUC50_UPK	"latitude_\`prov' !=." 	"& ECERS_structure_\`prov' >= 3.8 & ECERS_structure_\`prov' <." 	"Providers within \`dist' miles with ECERS >=50th pctile"
		prox HISTRUC75_UPK	"latitude_\`prov' !=." 	"& ECERS_structure_\`prov' >= 4.8 & ECERS_structure_\`prov' <." 	"Providers within \`dist' miles with ECERS >=75th pctile"		
		prox HISTRUC90_UPK	"latitude_\`prov' !=." 	"& ECERS_structure_\`prov' >= 6.0 & ECERS_structure_\`prov' <." 	"Providers within \`dist' miles with ECERS >=95th pctile"
		
		
		prox HI_CI_50_UPK 	"latitude_\`prov' !=." 	"& CLASS_I_\`prov' >= 3.1   & CLASS_I_\`prov' <." 	"Providers within \`dist' miles with CLASS I >=75th pctile"
		prox HI_CI_75_UPK   "latitude_\`prov' !=." 	"& CLASS_I_\`prov' >= 3.7   & CLASS_I_\`prov' <." 	"Providers within \`dist' miles with CLASS I >=75th pctile"
		prox HI_CI_90_UPK   "latitude_\`prov' !=." 	"& CLASS_I_\`prov' >= 4.2   & CLASS_I_\`prov' <." 	"Providers within \`dist' miles with CLASS I >=75th pctile"
		*/
		
		
		cap program drop prox_mean
		program define prox_mean
			args newvar expression xtracond label
			
			foreach dist in p25 p5 	{
			
				forvalues i = 1/${num_provs}	{
					gen `newvar'_`dist'_`i' = `expression'	if within_`dist'_`i'==1  `xtracond'
				}
				
				egen avg_`newvar'_`dist' = rowmean(`newvar'_`dist'_*)
				label var avg_`newvar'_`dist' "`label'"
					drop `newvar'_`dist'_*
				
			} //close dist loop
			
		end //Ends program prox
	 
		prox_mean ECERS	 	"ECERS_avg_\`i'" 	"" 	"ECERS avg"
	
	save "${anlys}/tract-level-supply_SL", replace
	saveold "${anlys}/tract-level-supply_v14_SL", version(14) replace
	
	
	**************************************************
	//Borough-level (collapsed from ACS microdata
	**************************************************
		
		use "${raw}\ACS NY population 2013-2017", clear
		
		//Limit to NYC in 2017
			keep if multyear ==.
			keep if year ==2017
			keep if county == 50 | county ==470 | county ==610 | county ==810 | county ==850 

			gen borough = ""
			replace borough = "Bronx"			if county ==50
			replace borough = "Brooklyn" 		if county ==470
			replace borough = "Manhattan"		if county ==610
			replace borough = "Queens"			if county ==810
			replace borough = "Staten Island"	if county ==850

		//Doubling up so I can put both the whole city & individual boros into a single figure	
			expand 2, gen(copy)
			replace borough = "NYC" if copy==1  

			gen hispanic = hispan !=0
			gen white = hispanic==0 & race==1
			gen black = hispanic==0 & race==2
			gen asian = hispanic==0 & (race==4 | race==5 | race==6)
			gen other = hispanic==0 & (race==3 | race>=7)

			gen wh_4 =  white==1 	& age==4
			gen bl_4 =  black==1 	& age==4
			gen hi_4 =  hispanic==1 & age==4
			gen as_4 = 	asian==1 	& age==4
			gen ot_4 =  other==1	& age==4

			gen all_4 = age==4

			gen all = 1

		//Collapse to borough level
			loc varlist "all white black hispanic asian other all_4 wh_4 bl_4 hi_4 as_4 ot_4"
			loc list ""

			collapse (sum) `varlist'  [fw=perwt], by(borough)

			encode borough, gen(boronum)
			drop borough

			order boronum
			gen id = _n
				
			save "${inter}\ACS estimates of 4 y-o", replace

	
	
************************
// Map data preparation
************************
	
	//Save subset of tract-level data for mapping
		use "${anlys}/tract-level-supply_SL", replace	
		keep id-borough num* any* avg*

		*Whiting out tracts that are public land (e.g., central park)
			foreach x of varlist pct*	{
				replace `x' = . if tract_num==471 //Greenwood Heights
				replace `x' = . if tract_num==1243 //Central Park			
			}

		rename intpt* intpt2*
	
		rename fulltract GEOID
		clonevar geoid = GEOID 

		save "${inter}/tract data for mapping", replace

			
	//Shapefiles		
		
		*Shapefile 1 - more natural-looking aspect ratio
			shp2dta using "${raw}/NYC tracts 2010 (normal aspect)", ///
				database("${inter}/mapping_aspect") coordinates("${anlys}/mapping_aspect-coord_SL") genid(id) replace
				*Using shp2dta rather than spshape2dta so I can name created databases separately
				
			use "${inter}/mapping_aspect", clear
			merge 1:1 geoid using "${inter}/tract data for mapping"
			drop if _merge !=3
			drop _merge
			
			destring aland, replace
			destring awater, replace
			
			gen area_tot = aland + awater
			
			drop if awater >=5000000 //Makes the map look considerably nicer, only drops 10 tracts

			save "${anlys}/mapping_aspect-data_SL", replace
				
	
		*Shapefile 2 - Uses lat/long coordinates (req for point mapping)	
			shp2dta using "${raw}/NY tracts 2010 (lat long)", ///
				database("${inter}/mapping_latlong") coordinates("${anlys}/mapping_latlong-coord_SL") genid(id) replace	
				*Using shp2dta rather than spshape2dta so I can name created databases separately
			
			use "${inter}/mapping_latlong", clear
			keep if COUNTYFP == "005" | COUNTYFP =="047" | COUNTYFP =="061" | COUNTYFP =="081" | COUNTYFP =="085"
			merge 1:1 GEOID using "${inter}/tract data for mapping"
			drop if _merge !=3
			drop _merge
			
			rename AFFGEOID tract_id
			
			save "${anlys}/mapping_latlong-data_SL", replace

			
	
