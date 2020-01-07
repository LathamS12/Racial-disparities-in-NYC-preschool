/*****************************************************************
* Purpose: Importing/cleaning NYC pre-k data files
* Author: Scott Latham
* Date created: 10/29/2018
* Last updated: 10/21/2019
*
*	Imports & merges the following files:
*
*	Provider-level
*		1. Pre-k directory
*		2. School locations
*		3. UPK quality
*		4. UPK demographics (enrollment 2015-2017)
*		5. Inspections data (includes private providers)
*
*	Tract-level
*		1. ACS tract population 2013-17
*		2. Tract centroids (& overlaid districts)
*		3. ACS poverty estimates 2011-15
*	
****************************************************************/

*****************
//Importing data
*****************
	
	//School directory (Variables suffixed with "dir" for later combining")
	**************************************************************************
		import delimited "${raw}/NYC_prek_directory_2018.csv", clear
			
		//Location identifier
			rename ïschooldbn dbn
			gen siteid = substr(dbn, -4, .)
			
		//Provider name
			rename locationname name
			
		//Address
			split final_address, parse(,)
			replace final_address1 = "320 Manhattan Avenue" if final_address1 == "320" //Only 1 stray observation
			rename final_address1 address
			
			drop final_address*
		
		//Census tract
			rename censustract tract
		
		//Income flag
			rename income_flg flag
			gen income_flg = flag != ""
				drop flag
		
		//Contact to apply
			gen contact_to_apply=programcode1=="Contact program to apply."
			
		//Dual & enhanced language programs
			
			*Dual
			gen dual_lang=0
			label var dual_lang "Dual language program"
			
			gen dual_lang_span=0
			label var dual_lang_span "Dual language program: Spanish"
					
			forvalues i =1/3	{
				gen pkcode`i' = substr(programcode`i', -2,.)
				
				replace dual_lang =1 if pkcode`i'=="SP" | pkcode`i'=="CH" | pkcode`i'=="BN"
				replace dual_lang_span = 1 if pkcode`i'=="SP"
			}
			
			*Enhanced
			gen enh_lang=0
			label var enh_lang "Enhanced language program"
			
			gen enh_lang_span=0
			label var enh_lang_span "Enhanced language program: Spanish"
			
			gen enh_lang_chin=0
			label var enh_lang_chin "Enhanced language program: Chinese"
			
			gen enh_lang_jewish=0
			label var enh_lang_jewish "Enhanced language program: Hebrew or Yiddish"
			
			replace enh_lang 			= 1 if enhancedlang_note != ""
			replace enh_lang_span 		= 1 if substr(enhancedlang_note, -7, .) == "Spanish"
			replace enh_lang_chin 		= 1 if substr(enhancedlang_note, -7, .) == "Chinese"
			replace enh_lang_jewish 	= 1 if substr(enhancedlang_note, -7, .) == "Yiddish" | substr(enhancedlang_note, -6, .)=="Hebrew"
			
			drop enhancedlang_note programcode* pkcode*
			
		//Length of day
			encode programname1, gen(length_cat)
			
			/*
			 length_cat 						|      Freq.     Percent      
			------------------------------------------------------------------
			1 - 5 Hour Program 					|          2        0.11   
			2 - Full-Day Program 				|      1,723       96.31   
			3 - Half-Day Program 				|         61        3.41   
			4 - Italian Dual Language Program 	|          1        0.06   
			5 - Spanish Dual Language Program 	|          2        0.11   
			------------------------------+-----------------------------------
									Total |      1,789      100.00
			*/
			
			gen full_day = length_cat==2 | length_cat==4 | length_cat==5
			//Verified that the 3 dual language programs here have 18 full-day seats each

			gen half_day = length_cat==3
			replace half_day = 1 if programname2=="Half-Day Program"
			
			drop length_cat programname*		
			
			/*
					   |       half_day
			  full_day |         0          1 |     Total
			-----------+----------------------+----------
					 0 |         2         61 |        63 
					 1 |     1,707         19 |     1,726 
			-----------+----------------------+----------
				 Total |     1,709         80 |     1,789 

			*/
	
		//Seats (classified as full, half, or 5 hour)
		// Need to parse and re-combine to calculate full & half-day seats
		
			split seats, parse(",") gen(seats_)
			split seats_1, gen(s1_p)
			split seats_2, gen(s2_p)
					
			/*
				*Note the 3 providers with 5 hour seats, 
					I've ignored them below
				
				  s1_p2 |      Freq.     Percent        Cum.
			------------+-----------------------------------
					  5 |          2        0.11        0.11
			   Full-Day |      1,726       96.48       96.59
			   Half-Day |         61        3.41      100.00
			------------+-----------------------------------
				  Total |      1,789      100.00

				  s2_p2 |      Freq.     Percent        Cum.
			------------+-----------------------------------
					  5 |          1        5.00        5.00
			   Half-Day |         19       95.00      100.00
			------------+-----------------------------------
				  Total |         20      100.00
			*/
	
			destring s1_p1 s2_p1, replace
			
			gen 	fd_seats = s1_p1 	if s1_p2 == "Full-Day"
			replace fd_seats = 0 		if s1_p2 != "Full-Day"

			gen 	hd_seats = s1_p1	if s1_p2 == "Half-Day"
			replace hd_seats = s2_p1	if s2_p2 == "Half-Day"
			replace hd_seats = 0		if s1_p2 != "Half-Day" & s2_p2 != "Half-Day"
			
			drop seats* s1* s2*
			
			// Locations file does not distinguish b/t full & half
			// Rather than sum, I've opted to pick the largest number 
			// between full or half. Correlates slightly better with
			// locations data, though both are quite high .885 vs .879
			
			egen seats = rowmax(hd_seats fd_seats) 
			//gen seats_sum = hd_seats + fd_seats
			
			
		//Meals	
			encode meals, gen(meal_cat)
			drop meals
			
			/*
			meal_cat 						|      Freq.     Percent     
			-------------------------------------------------------------
			1 - Breakfast 					|          2        0.11       
			2 - Breakfast/Lunch 			|        694       38.79    
			3 - Breakfast/Lunch/Snack(s) 	|        754       42.15
			4 - Contact program 			|        172        9.61
			5 - Lunch 						|          2        0.11
			6 - Lunch/Snack(s) 				|        157        8.78 
			7 - Snack(s) 					|          8        0.45
			-------------------------------------------------------------
			Total					 		|      1,789      100.00
			*/

			gen meals = 1 if meal_cat==1 | meal_cat==5 | meal_cat==7
			replace meals = 2 if meal_cat==2 | meal_cat==6
			replace meals = 3 if meal_cat==3
			replace meals = . if meal_cat==4
			
			drop meal_cat
			
			/*
				  meals |      Freq.     Percent        Cum.
			------------+-----------------------------------
					  1 |         12        0.67        0.67
					  2 |        851       47.57       48.24
					  3 |        754       42.15       90.39
					  . |        172        9.61      100.00
			------------+-----------------------------------
				  Total |      1,789      100.00
			*/

  
		//Play space
			encode play, gen(play_cat) 
			
			/*
			play_cat 											|      Freq.     Percent
			----------------------------------------------------------------------------
			1  - Contact program 								|        318       17.78
			2  - Indoor 										|         15        0.84
			3  - Indoor (Onsite) Playspace 						|         30        1.68
			4  - Indoor (Onsite)/Outdoor (Offsite) Playspace 	|          1        0.06 
			5  - Indoor/Outdoor (Offsite) Playspace 			|         77        4.30
			6  - Indoor/Outdoor (Onsite) Playspace 				|        897       50.14 
			7  - Indoor/Outdoor (Onsite) Playspace/Outdo 		|         15        0.84 
			8  - Outdoor (Offsite) Playspace 					|        101        5.65
			9  - Outdoor (Onsite) Playspace 					|        330       18.45
			10 - Outdoor (Onsite) Playspace/Outdoor (Offsite) 	|          5        0.28
			----------------------------------------------------------------------------
			Total						 						|      1,789      100.00
			*/
			
			gen indoor = play_cat>=2 & play_cat <=7
			replace indoor = . if play_cat==1
			
			gen outdoor = play_cat>=4
			replace outdoor = . if play_cat==1
			
			drop play play_cat
				
			/*
			 indoor 	|      Freq.     Percent     
			------------+---------------------------
					  0 |        436       24.37    
					  1 |      1,035       57.85    
					  . |        318       17.78    
			------------+---------------------------
				  Total |      1,789      100.00
					
			outdoor 	|      Freq.     Percent  
			------------+-------------------------
					  0 |         45        2.52  
					  1 |      1,426       79.71 
					  . |        318       17.78 
			------------+-------------------------
				  Total |      1,789      100.00
			*/	
		
		
		//Late/early pickup & hours of operation
			gen late_pickup = latepickup != "" 
			replace late_pickup = . if latepickup == "Contact program"
			
			gen early_drop = earlydropoff != ""
			replace early_drop = . if earlydropoff == "Contact program"

			gen hours_flg = hours != "" & hours != "Contact program"
			label var hours_flg "Provider hours of operation are listed in directory"
			
			drop latepickup earlydropoff hours
			
			/*
			late_pickup |      Freq.     Percent        Cum.
			------------+-----------------------------------
					  0 |        969       54.16       54.16
					  1 |        767       42.87       97.04
					  . |         53        2.96      100.00
			------------+-----------------------------------
				  Total |      1,789      100.00

							  
			 early_drop |      Freq.     Percent        Cum.
			------------+-----------------------------------
					  0 |      1,043       58.30       58.30
					  1 |        699       39.07       97.37
					  . |         47        2.63      100.00
			------------+-----------------------------------
				  Total |      1,789      100.00
			
			
			   Provider | 
			   hours of |
			  operation |
					 is |
			  available |      Freq.     Percent     
			------------+---------------------------
					  0 |        971       54.28    
					  1 |        818       45.72   
			------------+---------------------------
				  Total |      1,789      100.00
			*/
					
			
			
		//Uniforms & accessibility (missing these for too many obs., plus only in this dataset
			drop uniforms accessibility
			/*
			gen uniform = .
			replace uniform = 1 if uniforms == "Yes"
			replace uniform = 0 if uniforms == "No"
			label var uniform "Program requires uniform"
				drop uniforms	
			
			gen accessible = . 
			replace accessible = 1  if accessibility == "Fully Accessible" | accessibility == "Partially Accessible"
			replace accessible = 0  if  accessibility == "Not Accessible"
			replace accessible = .a if accessibility == "Contact program"
			label var accessible "Program is full/partially accessible"
				drop accessibility
			*/	
				
				
		//Add tags to indicate these vars come from directory file
			rename * *_dir	
			
			rename siteid_dir siteid
		
		gen flag_dir=1
		label var flag_dir "Provider is in directory data"
					
		save "${inter}/school directory", replace
	
	
	//School locations (Variables suffixed with "loc" for later combining") 
	***********************************************************************
		import delimited "${raw}/NYC_prek_locations_2018.csv", clear 
		
		//Provider name
			rename locname name
		
		//Location
		
			*Borough
			replace borough = "Brooklyn"   		if borough == "K"
			replace borough = "Manhattan"  		if borough == "M"
			replace borough = "Queens" 			if borough == "Q"
			replace borough = "Staten Island" 	if borough == "R"
			replace borough = "Bronx" 			if borough == "X"
			
			*District
				gen district = substr(sems_code, 1, 2)
			
				//Hate this, but need to make some manual changes (only affects 5 obs.)
					replace district = "02" if district == "2M"
					replace district = "03" if district == "3M"
					replace district = "09" if district == "9X"
			
					destring district, replace
				
			*Census tract
				rename censustract tract
				
				
		//Program characteristics
			//Meals
				/*		
					  MEALS |      						Freq.     Percent    
				------------+-----------------------------------------------
				  1 - Breakfast 				|         12        0.64  
				  2 - Breakfast/lunch 			|        501       26.58 
				  3 - Breakfast/lunch/snacks 	|        737       39.10
				  4 - Breakfast/snacks			|          8        0.42 
				  5 - Contact site directly		|        491       26.05 
				  6 - Lunch 					|          5        0.27   
				  7 - Lunch/snack				|         98        5.20 
				  8 - Snacks 					|         31        1.64
				  9 - No value					|          2        0.11
				------------------------------------------------------------
					  Total 					|      1,885      100.00

				*/
				
				recode meals (1 6 8 = 1) (2 4 7 = 2) (3=3) (5 9=.) 
				label var meals "Number of meals served"		
				
				/*				
				  Number of |
					  meals |
					 served |      Freq.     Percent   
				------------+-------------------------
						  1 |         48        2.55 
						  2 |        607       32.20    
						  3 |        737       39.10    
						  . |        493       26.15   
				------------+--------------------------
					  Total |      1,885      100.00
				*/
			
			
			//Playspace
				/*
					INDOOR_OUTDOOR |      													Freq.     Percent 
				----------------------------------------------------------------------------------------------
				 1 - Indoor playspace 												| 		  45		2.39	
				 2 - Indoor/outdoor (offsite) playspace								|         89        4.72     
				 3 - Indoor/outdoor (onsite) playspace								|        739       39.20     
				 4 - Indoor/outdoor (onsite) playspace / outdoor (offsite playspace)|         59        3.13       
				 5 - Playspace not offered											|          4        0.21       
				 6 - Outdoor (offsite) playspace 									|        108        5.73       
				 7 - Outdoor (onsite) playspace										|        357       18.94      
				 8 - Outdoor (onsite) playspace / outdoor (offsite) playspace		|         57        3.02    
				 9 - Contact site directly											|        427       22.65 
				---------------------------------------------------------------------------------------------
					Total 															|      1,885      100.00			
				*/
				
				gen indoor = indoor_outdoor >=1 & indoor_outdoor <= 4
				replace indoor = . if indoor_outdoor==9
				label var indoor "Indoor play area"
				
				gen outdoor = 1
				replace outdoor = 0 if indoor_outdoor==1 | indoor_outdoor==5
				replace outdoor = . if indoor_outdoor==9
				label var outdoor "Outdoor play area"	
				
				drop indoor_outdoor
				
				/*		
				Indoor play |
					   area |      Freq.     Percent   
				------------+--------------------------
						  0 |        526       27.90    
						  1 |        932       49.44    
						  . |        427       22.65   
				------------+--------------------------
					  Total |      1,885      100.00

					Outdoor |
				  play area |      Freq.     Percent    
				------------+--------------------------
						  0 |         49        2.60    
						  1 |      1,409       74.75    
						  . |        427       22.65    
				------------+--------------------------
				  Total |      1,885      100.00
				*/
				
				
			//Day length		
				/*
				 Day_Length |      				Freq.     Percent   
				-------------------------------------------------
				  1 - Full day 			|      1,778       94.32 
				  2 - Half & full day	|         10        0.53 
				  3 - Half day			|         84        4.46 
				  4 - 5 hour 			|          7        0.37 
				  5 - Full + 5 hour		|          6        0.32
				-------------------------------------------------
					  Total 			|      1,885      100.00
				*/
				
				gen full_day = .
				replace full_day = 1 if day_length==1 | day_length==2 | day_length==5
				replace full_day = 0 if day_length ==3 | day_length==4
				
				gen half_day = .
				replace half_day = 1 if day_length==2 | day_length==3
				replace half_day = 0 if day_length==1 | day_length==4 | day_length==5
				
				drop day_length
					
				/*			 
						   |       half_day
				  full_day |         0          1 |     Total
				-----------+----------------------+----------
						 0 |         7         84 |        91 
						 1 |     1,784         10 |     1,794 
				-----------+----------------------+----------
					 Total |     1,791         94 |     1,885 

				*/
				
				//Income flag
				gen income_flg = substr(note, 12, 5)=="Alert" //Full message is "Alert: Program may have income or other eligibility requirements
					drop note
			
		//Building Identification Number
			destring bin, ignore(",") replace
		
		//Add tags to indicate these come from the locations file
			rename * *_loc
		
		//Unique identifiers
			rename sems_code dbn
			rename ïloccode siteid
		
			gen flag_loc = 1
			label var flag_loc "Provider is in locations data"
		
		save "${inter}/pre-k school locations", replace
	
	
	//Program quality (Variables suffixed with "qual" for later combining")
	***********************************************************************
		import delimited "${raw}/NYC_prek_quality_2017.csv", clear 		
		
		duplicates drop //Drop duplicate observations (just 3)
		
		drop enrollment 
		//This var matches exactly with 2016-17 enrollment (from dem file) + has 65 observations
		//that aren't in that dataset. Decided not to use it for consistency across years
			
		rename programname name
		rename programtype prek_type
		
		rename programcode dbn
		
		rename siteid siteid2
		gen siteid = substr(dbn, -4, .) //Just using final 4 characters, they provide a unique ID
		order siteid, first
			drop siteid2
		
		//Program location.
			rename address1 address
			
			*Zip
				gen postcode = substr(address2, -5,.)
				destring postcode, replace
					drop address2
			
			*District
				gen district = substr(dbn, 1, 2)
				destring district, replace
				
			*Borough
				gen borough = "Manhattan" 			if district >=1 & district <=6
				replace borough = "Bronx" 			if district >=7 & district <=12
				replace borough = "Brooklyn"		if (district >=13 & district <=23) | district==32
				replace borough = "Queens"			if district >=24 & district <=30
				replace borough = "Staten Island"	if district ==31
				
				//Supplementing for district 84
				replace borough = "Manhattan" 		if substr(siteid, 1, 1)=="M"
				replace borough	= "Bronx" 			if substr(siteid, 1, 1)=="X"
				replace borough	= "Brooklyn"		if substr(siteid, 1, 1)=="K"
				replace borough	= "Queens"			if substr(siteid, 1, 1)=="Q"
				replace borough	= "Staten Island" 	if substr(siteid, 1, 1)=="R"
							
				/*					   
					  borough |      Freq.     Percent        Cum.
				--------------+-----------------------------------
						Bronx |        369       18.64       18.64
					 Brooklyn |        666       33.64       52.27
					Manhattan |        280       14.14       66.41
					   Queens |        542       27.37       93.79
				Staten Island |        123        6.21      100.00
				--------------+-----------------------------------
						Total |      1,980      100.00
				*/

		//Program chars
		
			*Full v half day
				encode lengthofprekday, gen(length_cat)
				
				/*
				 Length of Pre-K Day 			| 		Freq.     Percent    
				----------------------------------------------------------
				1 - 5-Hour 						|          2        0.10    
				2 - Both full day and 5-hour 	|          1        0.05    
				3 - Both half day and full day 	|         19        0.96   
				4 - Full day 					|      1,715       86.62   
				5 - Half day 					|         56        2.82    
				6 -	N/A 						|        187        9.43    
				-----------------------------------------------------------
										  Total |      1,980      100.00
				*/
						 
				gen full_day = length_cat==2 | length_cat==3 | length_cat==4
				replace full_day = . if length_cat==6
				
				gen half_day = length_cat==3 | length_cat==5
				replace half_day = . if length_cat==6
				
				drop length_cat lengthofprekday
			
				/*		
						   |             half_day
				  full_day |         0          1          . |     Total
				-----------+---------------------------------+----------
						 0 |         2         56          0 |        58 
						 1 |     1,716         19          0 |     1,735 
						 . |         0          0        187 |       187 
				-----------+---------------------------------+----------
					 Total |     1,718         75        187 |     1,980 
				*/
				
			*Dual language
				//We have dual language but not enhanced language in this dataset
				// Decided to split into 2 vars, but they have different missingness
				// because of the discrepancy
				
				gen dual_lang = duallanguage != ""			
				gen dual_lang_span = strpos(duallanguage, "Spanish") >0
				drop duallanguage
				
			*Meals
				encode meals, gen(meals_cat)
				drop meals
				
				/*
				meals_cat 									|      Freq.     Percent
				-------------------------------------------------------------------------
				1 - Breakfast 								|          3        0.15  
				2 - Breakfast / Lunch / Snack(s) 			|          1        0.05   
				3 - Breakfast/Lunch 						|        681       34.39   
				4 -	Breakfast/Lunch/Snack(s) 				|        778       39.23    
				5 -	Breakfast/Snack(s) 						|          2        0.10    
				6 -	Contact program 						|          1        0.05   
				7 - Contact program directly for details 	|        161        8.12  
				8 - Lunch 									|          2        0.10 
				9 -	Lunch/Snack(s) 							|        160        8.07 
				10 - N/A 									|        184        9.28
				11 - Snack(s) 								|          7        0.35
				-------------------------------------------------------------------------
				 Total 										|      1,980      100.00
				*/
				
				gen meals = .
				replace meals = 1 if meals_cat==1 | meals_cat==8 | meals_cat==11
				replace meals = 2 if meals_cat==3 | meals_cat==5 | meals_cat==9
				replace meals = 3 if meals_cat==2 | meals_cat==4
				
				drop meals_cat
				
				/*		
				 meals_qual |      Freq.     Percent   
				------------+--------------------------
						  1 |         12        0.61   
						  2 |        843       42.58   
						  3 |        779       39.34   
						  . |        346       17.47  
				------------+-------------------------
					  Total |      1,980      100.00
				*/
			
			*Playspace
				encode playspace, gen(play_cat)
		
			/*
				play_cat									|      Freq.     Percent   
				---------------------------------------------------------------------
				1 - Indoor 									|         43        2.17   
				2 - Indoor/Outdoor (offsite) playspace 		|         83        4.19   
				3 - Indoor/Outdoor (onsite) playspace 		|        910       45.89   
				4 - Indoor/Outdoor (onsite) playspace/Outdo |         15        0.76   
				5 -	N/A								 		|        187        9.43    
				6 -	Outdoor (offsite) playspace 			|        109        5.50    
				7 - Outdoor (onsite) playspace 				|        346       17.45    
				8 - Outdoor (onsite) playspace/Outdoor		|          7        0.35   
				9 - Please contact site for more informatio |        280       14.14   
				------------------------------------------------------------------
													  Total |      1,980      100.00
			*/

				gen indoor = play_cat>=1 & play_cat<=4
				replace indoor=. if play_cat==5 | play_cat==9
				
				gen outdoor = (play_cat >=2 & play_cat <=4) | (play_cat>=6 & play_cat <=8)
				replace outdoor=. if play_cat==5 | play_cat==9
				
				drop play_cat playspace
				
				/*
					 indoor |      Freq.     Percent        Cum.
				------------+-----------------------------------
						  0 |        462       23.33       23.33
						  1 |      1,051       53.08       76.41
						  . |        467       23.59      100.00
				------------+-----------------------------------
					  Total |      1,980      100.00


					outdoor |      Freq.     Percent        Cum.
				------------+-----------------------------------
						  0 |         43        2.17        2.17
						  1 |      1,470       74.24       76.41
						  . |        467       23.59      100.00
				------------+-----------------------------------
					  Total |      1,980      100.00
				*/

		
			*Late pickup & early dropoff
				gen late_pickup = latepickup == "Yes"
				replace late_pickup = . if latepickup=="N/A"
				
				gen early_drop = earlydrop == "Yes"
				replace early_drop = . if earlydrop == "N/A"
				
				drop latepickup earlydrop
					
				/*				
				late_pickup |		 Freq.     Percent        Cum.
				------------+-----------------------------------
						  0 |        969       48.94       48.94
						  1 |        827       41.77       90.71
						  . |        184        9.29      100.00
				------------+-----------------------------------
					  Total |      1,980      100.00

				early_drop_ |      Freq.     Percent        Cum.
				------------+-----------------------------------
						  0 |      1,038       52.42       52.42
						  1 |        758       38.28       90.71
						  . |        184        9.29      100.00
				------------+-----------------------------------
					  Total |      1,980      100.00	  
				*/
				

		*Add tags to indicate these come from quality file (can't do with * command because some names are too long)
			foreach x of varlist name prek_type address-early_drop	{
				rename `x' `x'_qual
			}
			
			gen flag_qual = 1	
			label var flag_qual "Provider is in quality data"
		
		save "${inter}/pre-k quality", replace


	//Demographics - 2015/16-2017/18 (Variables suffixed with "dem" for later combining")
	********************************************************************************	
		use "${raw}\RANYCS UPK enrollment x race (2015-2017)", clear

		rename num_students enrollment
		rename zip postcode
		
		order enrollment *female *male *white *black *hisp *asian *other
		
		*New variable that separates pre-k centers from other DOE, collapses NYCEECs (to match with dir/qual/loc data).
			gen prek_type = ""
			replace prek_type = "NYCEEC" 		if site_type=="ACS" | site_type=="DOE"
			replace prek_type = "DOE" 			if site_type=="PS" | site_type=="DOE Public School" | site_type=="Special Education"
			replace prek_type = "Pre-K Center" 	if site_type=="PS - PreK Center"
			replace prek_type = "Charter" 		if site_type=="Charter School"
			replace prek_type = "" if year==2015
		
		*Use site type variables in 2016/17 for ACS vs. DOE funding breakdown for NYCEECS
			gen NYCEEC_ACS = site_type=="ACS" 				if year !=2015
			gen NYCEEC_DOE = site_type=="DOE" 				if year !=2015
			gen DOE_sped = site_type=="Special Education" 	if year !=2015
		
		*Make 2015-2017 comparable in 1 variable
			replace site_type = "DOE Public School" if site_type=="PS" | site_type=="DOE Public School" | site_type=="Special Education" | site_type=="PS - PreK Center"
			replace site_type = "NYCEEC" if site_type=="ACS" | site_type=="DOE"
		
			
			gen half_day = num_hd >0
			gen full_day = num_fd >0
			
		//Reshape to program level
			rename * *_
			rename year_ year
			rename siteid_ siteid
			
			reshape wide enrollment-pct_other name prek_type_ NYCEEC* DOE_sped num_fd num_hd half_day full_day postcode , i(siteid) j(year)
				
		
			//Collapse vars that are essentially the same across years
				* might have differential missingness, or slight variations (e.g. name)
	
				foreach var in name prek_type postcode NYCEEC_ACS NYCEEC_DOE	{
					
					cap confirm numeric variable `var'_2015
					
					*Create new int or string depending on the var
					if !_rc	{
						gen `var'_dem = .
						di "int"
						forvalues i = 2015/2017	{
							replace `var'_dem = `var'_`i' if `var'_dem==.
						}
					}
					else	{
						gen `var'_dem = ""
						di "str"
						forvalues i = 2015/2017	{
							replace `var'_dem = `var'_`i' if `var'_dem==""
						}
					}
					drop `var'_????
				} //close var loop

			
			//Borough
				gen borough_dem = ""
				replace borough_dem = "Brooklyn" 		if substr(siteid, 1, 1)=="K"
				replace borough_dem = "Bronx" 			if substr(siteid, 1, 1)=="X"
				replace borough_dem = "Manhattan"		if substr(siteid, 1, 1)=="M"
				replace borough_dem = "Queens"			if substr(siteid, 1, 1)=="Q"
				replace borough_dem = "Staten Island"	if substr(siteid, 1, 1)=="R"
			
			
			/*
			
			//Missing values are all pre-k centers, siteids are prefixed with "Z"			
						
			  borough_dem |      Freq.     Percent        
			--------------+-----------------------------
						  |         86        4.21       
					Bronx |        373       18.25      
				 Brooklyn |        648       31.70     
				Manhattan |        280       13.70       
				   Queens |        536       26.22      
			Staten Island |        121        5.92     
			--------------+-----------------------------
					Total |      2,044      100.00

			*/
			
			//Indicators for program entry/exit
				gen stayer = enrollment_2015 !=. & enrollment_2016 !=. & enrollment_2017 !=.
				label var stayer "Program was in operation all 3 years"
				
				gen exit = enrollment_2015 !=. & enrollment_2017 ==.
				label var exit "Program operated in 2015, not in 2017"
				
				gen entry = enrollment_2015 ==. & enrollment_2017 !=.
				label var entry "Program not in operation in 2015, open by 2017"
				
				gen exit_entry_cat = .
				replace exit_entry_cat = 1 if stayer==1
				replace exit_entry_cat = 2 if exit==1
				replace exit_entry_cat = 3 if entry==1
				
				label define ex_en 1 "stayer" 2 "exit" 3 "entry"
				label values exit_entry_cat ex_en
				label var exit_entry_cat "1=Stayer, 2=exit, 3=entry"
				
				/*
				For now, just keeping half day from 2017
				*/
				
				drop half_day_2016 half_day_2015 full_day_2016 full_day_2015
				
				rename half_day_2017 half_day_dem
				rename full_day_2017 full_day_dem
				
				gen flag_dem=1
				label var flag_dem "Provider is in demographics data"
				
		save "${inter}/3 yr demographics", replace
	
	
	//Health inspections - at the violation level (Variables suffixed with "ins" for later combining")
	***************************************************************************************************
		//Merge geocoded locations (geocoded by me) with inspections data
			import delimited "${raw}/Geocoded child care addresses.csv", clear //Geocoded by me
			save "${inter}/inspections latlong", replace
			
			import excel "${raw}/DOHMH inspections data 2011-2017.xlsx", ///
				sheet("2014-2017") cellrange(A10:Y62179) firstrow clear

			rename _all, lower
			merge m:1 dc_id using "${inter}/inspections latlong"

			save "${inter}/CC inspections with latlong", replace	

		//Prep inspections data for merging
			use "${inter}/CC inspections with latlong", clear
		
			keep if programtype== "PRESCHOOL" //Dropping infant/toddler providres
			keep dc_id-longitude county zip placefips-censusblockgroup
			
			gen UPK = upkflag=="Y"
			label var UPK "UPK program"
			
			*Rename vars
				rename zipcode postcode
				
				rename censustractcode tract
				tostring tract, replace
				
				rename aka name
				
				drop capacity 
				//Doesn't match at all with capacity var from other
				//datasets, so don't really know what it's measuring
			
			*Create new vars for merging
				gen siteid = doe_id
				replace siteid = dc_id if doe_id == "NULL"

				gen prek_type 		= "NYCEEC" if UPK==1
				replace prek_type 	= "Private" if UPK==0
				
				gen borough = ""
				replace borough = "Queens"			if county == "Queens County"
				replace borough = "Brooklyn"		if county == "Kings County"
				replace borough = "Manhattan" 		if county == "New York County"
				replace borough = "Bronx"			if county == "Bronx County"
				replace borough = "Staten Island" 	if county == "Richmond County"
			
			*Generate "school year" & "calendar year"
				gen cal_year = year(visitdate)
				
				gen sch_year = year(visitdate)
				replace sch_year = sch_year - 1 if month(visitdate)<9
				
				forvalues i = 2014/2017	{
					gen cyear_`i' = cal_year==`i'
					gen syear_`i'= sch_year==`i'
				}
				
				
			*Collapse from violation level to site level (to match other datasets)
				loc firstvars "name address borough postcode tract prek_type latitude longitude UPK  "
				loc maxvars "cyear_* syear_* cyear_max=cal_year syear_max=sch_year "
				
				collapse (first) `firstvars' (max) `maxvars' , by(siteid)
				
			
			*Tag variables to indicate they came from inspections data
				foreach x of varlist name-longitude	{
					rename `x' `x'_ins
				}
			
				gen flag_ins=1 
				label var flag_ins "Provider is in inspections data"
			
			save "${inter}/inspections data", replace

		
	// Merge the universe of provider-level data 
	*********************************************	
		use "${inter}/school directory", clear
		merge 1:1 siteid using "${inter}/pre-k quality", nogen
		merge 1:1 siteid using "${inter}/pre-k school locations", nogen
		merge 1:1 siteid using "${inter}/3 yr demographics", nogen

		//2093 providers total across these four datasets	
		
		merge 1:1 siteid using "${inter}/inspections data", nogen
		//Merge rate is expected to be much lower here, adding non UPK providers

		
		replace UPK = 1 if UPK==.	
		label var UPK "Universal Pre-k provider"
		//UPK variable comes from inspections data, which includes private providers. 
		//Any observations not in inspections data are UPK
			
		/*15 UPK providers that are in the inspections data but not the four OpenData datasets
			for a total of 2108 UPK providers
		
			tab UPK

					UPK |      Freq.     Percent   
			------------+--------------------------
					  0 |      1,334       38.76   
					  1 |      2,108       61.24   
			------------+--------------------------
				  Total |      3,442      100.00
		*/
		
		order flag*, first //Useful for diagnostics
		recode flag* (.=0)
		
		save "${inter}/NYC merged provider-level pre-k", replace	
	

***********************************************************************************	
	
	//Census tract-level data
	**********************************
		
		//Tract-level population estimates
			use "${raw}\ACS tract population 2013-2017", clear
			keep if STATE=="36" //Keep NY
			keep if COUNTY == "005" | COUNTY =="047" | COUNTY =="061" | COUNTY =="081" | COUNTY =="085"				
			
			rename FIPS fulltract
			rename A00002_003 area_land
			rename A01001_001 total_pop 
			
			//Total (Hisp + non-Hisp)
				rename A03001_002 total_white
				rename A03001_003 total_black
				rename A03001_004 total_aian
				rename A03001_005 total_asian
				rename A03001_006 total_hpi
				rename A03001_007 total_oth
				rename A03001_008 total_trc
				
			//Only Hispanic
				rename A04001_010 hisp_all
				rename A04001_011 hisp_white
				rename A04001_012 hisp_black
				rename A04001_013 hisp_aian
				rename A04001_014 hisp_asian
				rename A04001_015 hisp_hpi
				rename A04001_016 hisp_oth
				rename A04001_017 hisp_trc
			
			//Categorical, including Hispanic (includes MOE)
				rename (B03002001 B03002001s) 	(total 	total_moe)
				rename (B01001I001 B01001I001s) (hisp 	hisp_moe)
				rename (B03002003 B03002003s)	(white 	white_moe)
				rename (B03002004 B03002004s)	(black	black_moe)
				rename (B03002006 B03002006s)	(asian 	asian_moe)
	
				rename (B03002005 B03002005s) 	(aian 	aian_moe)
				rename (B03002007 B03002007s) 	(hpi 	hpi_moe)
				rename (B03002008 B03002008s) 	(oth 	oth_moe)
				rename (B03002009 B03002009s) 	(trc 	trc_moe)
				
				gen other = aian + hpi + oth + trc
				
				 //Formula for MOE of sum (per ACS documentation)
				 *More complicated because I have to account for 0s
					gen any_0=0
					gen largest_0_sq=0
					
					foreach x in aian hpi oth trc	{
						gen `x'_moe2 = `x'_moe^2
						replace `x'_moe2 = . if `x'==0
						
						replace any_0 = 1 if `x'==0
						replace largest_0_sq = `x'_moe^2 if (`x'_moe^2 > largest_0_sq) & `x'==0 
					}
					
					//Summing squared MOEs, then adding only the largest squared MOE for groups with 0 pop
						egen new = rowtotal(aian_moe2 hpi_moe2 oth_moe2 trc_moe2)
						replace new = new + largest_0 if any_0==1
					
					//Taking the sqrt to get the MOE of the sum
					gen other_moe = sqrt(new)
					

			//Kids under 5 (no MOEs)
				rename A01001_002 under5_all
				gen fours_total = under5_all/5

				*Total (including Hisp/Latino)
					gen under5_white 	= B01001A003 + B01001A018 //White, including Hispanic/Latino
					gen under5_black 	= B01001B003 + B01001B018
					gen under5_aian 	= B01001C003 + B01001C018
					gen under5_asian 	= B01001D003 + B01001D018
					gen under5_hpi 		= B01001E003 + B01001E018
					gen under5_oth	 	= B01001F003 + B01001F018
					gen under5_trc 		= B01001G003 + B01001G018
					gen under5_hisp 	= B01001I003 + B01001I018
				
				
				*I want a measure of the number of non-Hispanic children under 5 by race,
				* but Hispanic v. non-Hispanic is not disaggregated by age
				
					//Instead, I use the following procedure:
						foreach grp in white black aian asian hpi oth trc	{
						
							//1. Calculate the proportion of each group that are Hispanic
							gen proportion_`grp'_hisp = hisp_`grp' / total_`grp'	
							
							//2. Use this proportion to estimate the number of Hispanic kids <5 for each group 
							gen under5_`grp'_hisp = under5_`grp' * proportion_`grp'_hisp
							
							//3. Subtract this number from the number of kids under 5 by race
							gen under5_`grp'_nohisp = under5_`grp' - under5_`grp'_hisp
							
							//4. Replace missing values with 0s (places with no one of a given group)
							replace under5_`grp'_nohisp = 0 if under5_`grp'_nohisp == . 
						}
					
					//Create proportion variables	
						foreach grp in white black aian asian hpi oth trc		{
							gen pr_`grp'	 = (`grp' / total_pop)
							gen pr_`grp'_u5 =  (under5_`grp'_nohisp / under5_all)
						}
					
						gen pr_hisp    = (hisp_all / total_pop)	
						gen pr_hisp_u5 = (under5_hisp /under5_all)
						
						gen pr_blhisp = pr_black + pr_hisp
						gen pr_blhisp_u5 = pr_black_u5 + pr_hisp_u5


				*Redefine "other" category to include multi-race, aian, HPI
					gen pr_other = 0
					gen pr_other_u5 = 0

					foreach x in trc hpi aian other	{
						replace pr_other 	= pr_other 		+ pr_`x' 		if pr_`x' 	!=.
						replace pr_other_u5 = pr_other_u5 	+ pr_`x'_u5 	if pr_`x'_u5 !=.
					}
							
				*Create percent variables in addition to proportions
					foreach var in white black hisp asian other blhisp	{
						gen pct_`var' 		= 100*pr_`var'
						gen pct_`var'_u5 	= 100*pr_`var'_u5
					}

				keep fulltract total* white* black* asian* hisp* other* pct* fours_total area
				save "${inter}/Census tract-level child population estimates", replace
				

		//Creates a census tract to school district crosswalk by overlaying tract centroids into
		// a school district map
		
			tempfile file //Will store the crosswalk before merging
		
			cd "${raw}"
			spshape2dta "NYC school districts", replace
			
			use "NYC school districts", clear
			keep _ID school_dis
			save `file'
	 		 
			use "${raw}/NYC tract centroids latlong", clear
			destring intptlat intptlon, replace
			geoinpoly intptlat intptlon using "NYC school districts_shp"
	
			merge m:m _ID using `file', nogen
			drop _ID
			
			save "${inter}/Tract centroids & districts", replace
		
		 
	//Merge across Census data
		use "${raw}/Census NYC poverty 2011-2015", clear
		keep if year =="2015"
		
		rename tract fulltract
	
		merge 1:1 fulltract using "${inter}/Tract centroids & districts", nogen

		merge 1:1 fulltract using "${inter}/Census tract-level child population estimates.dta"
			drop if _merge ==2
			drop _merge
		
		//Clean merged census data
		gen id = 1
		gen tract_num = _n
		
		destring pop10, replace
		
		//SES composite
			factor unemploy poverty publicassist pvacant, pcf
			predict SES
			
			factor unemploy poverty publicassist pvacant, pf
			predict SES2
			
			rename poverty pct_pov
			
			gen popden = poprace / area_land
			
			replace SES = SES*-1
			label var SES "SES composite (pcf)"
		
			replace SES2 = SES2*-1
			label var SES2 "SES composite (pf)"
			
		//Boroughs (same as counties, just renaming)
			gen borough = ""
			replace borough = "Manhattan"		if county == "New York County"
			replace borough = "Queens"			if county == "Queens County"
			replace borough = "Brooklyn"		if county == "Kings County"
			replace borough = "Staten Island"	if county == "Richmond County"
			replace borough = "Bronx" 			if county == "Bronx County"
		
		keep id fulltract tract_num area_land intpt* pct* pop* SES* borough fours pvacant school_dis
		order id fulltract tract_num area_land	
		
		save "${inter}/Clean tract-level data", replace

	