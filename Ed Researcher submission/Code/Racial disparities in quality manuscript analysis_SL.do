/**********************************************************************
* Purpose: Estimates regressions for the NYC project
* Author: Scott Latham
* Date created: 12/14/2018
* Last modified: 10/11/2019
********************************************************************/

	//Table 1 borough X provider type  - at some point may want to clean this code up
	***********************************************************************************
		use "${anlys}/provider-level_SL", clear 
		tab borough prek_type if samp_2017==1, row mi

		
		//Tabulation quality over same groups			
		
		//ECERS
		mat table = J(1,7,.)
		foreach x in bronx brooklyn manhattan queens staten	{	
			mat row = [.]
			
			sum ECERS_avg if samp_2017 & `x'==1
				loc m: di %3.2f r(mean)
				mat row = [row,`m']
				
			forvalues i = 1 /5	{
				sum ECERS_avg if samp_2017 & `x'==1 & sector ==`i'
				loc m: di %3.2f r(mean)
				mat row = [row,`m']
				
			}
			mat table = [table \ row]
		}
		
		mat colnames table = x All DOE_k12 DOE_pk NYCEEC Charter priv
		mat rownames table = x bronx brooklyn manhattan queens staten
		mat list table
		
		putexcel set "${output}\Tables\ECERS means by sector & borough", replace
		putexcel A1 = matrix(table), names
			
			
		//CLASS
		mat table = J(1,7,.)
		foreach x in bronx brooklyn manhattan queens staten	{	
			mat row = [.]
			
			sum CLASS_avg if samp_2017 & `x'==1
				loc m: di %3.2f r(mean)
				mat row = [row,`m']
				
			forvalues i = 1 /5	{
				sum CLASS_avg if samp_2017 & `x'==1 & sector ==`i'
				loc m: di %3.2f r(mean)
				mat row = [row,`m']
				
			}
			mat table = [table \ row]
		}
		
		mat colnames table = x All DOE_k12 DOE_pk NYCEEC Charter priv
		mat rownames table = x bronx brooklyn manhattan queens staten
		mat list table
		
		putexcel set "${output}\Tables\CLASS means by sector & borough", replace
		putexcel A1 = matrix(table), names
		
		
		
		
	//Table 2 - pct of kids in UPK by boro & race
	**********************************************
		use "${anlys}/provider-level_SL", clear 
		
		expand 2, generate(copy)

		//drop all
		drop if borough ==.
		
		gen all = copy==0
		replace borough = 0 if all

		loc boros "bronx brooklyn manhattan all queens staten"
		
		collapse (sum) enrollment_2017 num*2017 (mean) `boros', by(borough)
		
		mat table = J(1, 7, .)
		foreach boro in `boros'	{
			mat row = [.]
				
			sum enrollment_2017 if `boro'==1
				mat row = [row , r(mean)]

			foreach x in white black hisp asian other	{
				sum num_`x'_2017 if `boro'==1
				loc m: di %3.2f r(mean)
				
				mat row = [row , `m']
				
			} //ends x loop
			
			mat table = [table \ row]
			mat list table
			
		} //ends boro loop

		mat rownames table = blank `boros'
		mat colnames table = "" all_2017 wh_2017 bl_2017 hi_2017 as_2017 ot_2017
		mat list table
		
		clear
		svmat table, names(col)
		drop in 1
		gen id = _n
		
		
		//Merge with ACS estimates of 4 y/o
			merge 1:1 id using "${inter}\ACS estimates of 4 y-o", nogen
				drop id
				
			foreach x in all wh bl hi as ot	{
				gen pct_`x'_upk = (`x'_2017 / `x'_4) * 100
			}
			
			order *upk /*prek *sch */
		
		//Reorder to put NYC at top
			recode boronum (4=1) (1=2) (2=3) (3=4)  
			sort boronum
			gen boro_id = _n
			
			label define boros 1 "All NYC" 2 "Bronx" 3 "Brooklyn" 4 "Manhattan" 5 "Queens" 6 "Staten Island"
			label values boro_id boros
			
			
		//Save as table 	
			mkmat boronum pct*upk /*pct*prek pct*sch*/, matrix(table)
			
			putexcel set "${output}\Tables\T2 - UPK enrollment by race X boro", replace
			putexcel A1 = matrix(table), names
			
			save "${inter}/attendance by race X boro (for graphing)", replace
			
		


	//Tables 3a, 4a, 6a
	**********************
		cap program drop descrip_by_race
		program descrip_by_race
			args dvs xtracond title samp
					
			use "${anlys}/provider-level_SL", clear
			
			loc fmt "%3.2f" //Format
			gen blank = .
			
			loc varnames ""
			
			mat table = J(1,16,.)
			
			foreach dv of varlist `dvs' {
				
				loc varnames = "`varnames' `dv'"
				mat row = [.]
				
				loc tot_SD = 0 //Total SD (for calculating white-XX gap sizes)
				loc wh_mean = 0 //White mean (for calculating white-XX gaps)
				
				foreach x in enrollment num_white num_black num_hisp num_asian	{
					
					sum `dv'	[aw=`x'_2017] 	if `samp'==1 	`xtracond'
		
					//Overall means
					loc m: 		di `fmt' r(mean)
					loc sd: 	di `fmt' r(sd)
	
					mat row = [row, `m', `sd', .]
					mat list row		
			
				}				
				mat table = [table \ row]
			}
			
			mat rownames table = "" `varnames'
			mat colnames table = blank m_all SD_all blank m_wh SD_wh blank m_bl SD_bl blank m_hi SD_hi blank m_as SD_as  
			mat list table
			
			putexcel set "${output}/Tables/provider-level descriptives (`title' `samp')", replace
			putexcel A1 = matrix(table), names
		
		end //Ends program descrip_by_race
	
		descrip_by_race "enrollment_2017 pct_white_2017 pct_black_2017 pct_hisp_2017 pct_asian_2017 pct_other_2017" 					""		"Table 3a"	 "samp_2017"
		descrip_by_race "ECERS_avg-ECERS_structure CLASS_avg-CLASS_I"				 													""		"Table 4a" 	 "samp_2017"
		descrip_by_race "DOE DOE_k12 DOE_pk NYCEEC full_day half_day seats dual_lang enh_lang income_req  meals-late_pickup"			""		"Table 6a"	 "samp_2017"
		
		descrip_by_race "enrollment_2017 pct_white_2017 pct_black_2017 pct_hisp_2017 pct_asian_2017 pct_other_2017" 					""		"Table 3a"	 "samp_qual"
		descrip_by_race "ECERS_avg-ECERS_structure CLASS_avg-CLASS_I"																	""		"Table 4a" 	 "samp_qual"
		descrip_by_race "DOE DOE_k12 DOE_pk NYCEEC full_day half_day seats dual_lang enh_lang income_req  meals-late_pickup"			""		"Table 6a"	 "samp_qual"
		
		
	//Tables 3b, 4b, 6b
	**********************
		cap program drop gaps_by_race
		program gaps_by_race
			args dvs xtracond title std samp
					
			use "${anlys}/provider-level_SL", clear
			
			loc fmt "%3.2f" //Format
			gen blank = .
			
			loc varnames ""
			
			mat table = J(1,7,.)
			
			foreach dv of varlist `dvs'  {
				
				loc varnames = "`varnames' `dv'"
				mat row = [.]
				
				sum `dv'	[fw=enrollment_2017] 	if `samp'==1 	`xtracond'
					loc tot_sd = r(sd)
										
				foreach x in white black hisp asian	{
					
					mean `dv'	[fw=num_`x'_2017] 	if `samp'==1 	`xtracond'
					mat m = e(b)
					mat v = e(V)
					
					loc `x'_mean = m[1,1]
					loc `x'_SE = sqrt(v[1,1])
					
					loc `x'_lb = ``x'_mean' - (1.96*``x'_SE')
					loc `x'_ub = ``x'_mean' + (1.96*``x'_SE')
					
				} //close x loop
				
				foreach x in black hisp asian	{
					loc `x'_white_sig = 0				
					
					if "`std'" == "std"		loc `x'_white_gap: di %5.3f (``x'_mean'-`white_mean') / `tot_sd'
					if "`std'" == "nstd"	loc `x'_white_gap: di %5.3f (``x'_mean'-`white_mean')
					
					di "`x' lb: ``x'_lb' , `x'_ub: ``x'_ub'"
					di "wh_lb: `white_lb' , wh_ub: `white_ub'"

					if ``x'_lb' > `white_ub' | ``x'_ub' < `white_lb'	{
						loc `x'_white_sig = 1 
					}
				
					mat row = [row, ``x'_white_gap', ``x'_white_sig']
				
				} //close x loop
								
				mat table = [table \ row]
				
			} //Close dv loop
			
			mat rownames table = "" `varnames'
			mat colnames table = blank wh_bl wh_bl_sig wh_hi wh_hi_sig wh_as wh_as_sig  
			mat list table
			
			putexcel set "${output}/Tables/racial gaps in descriptives (`title' `samp')", replace
			putexcel A1 = matrix(table), names
		
		end //Ends program gaps_by_race
		
		gaps_by_race "enrollment_2017 pct_white_2017 pct_black_2017 pct_hisp_2017 pct_asian_2017 pct_other_2017" 			""		 "Table 3b" 	"nstd"	"samp_2017"
		gaps_by_race "ECERS_avg-ECERS_structure CLASS_avg-CLASS_I" 															""		 "Table 4b" 	"std"   "samp_2017"
		gaps_by_race "DOE DOE_k12 DOE_pk NYCEEC full_day half_day seats dual_lang enh_lang income_req  meals-late_pickup " 	""		 "Table 6b" 	"nstd"  "samp_2017"
		
		
		gaps_by_race "enrollment_2017 pct_white_2017 pct_black_2017 pct_hisp_2017 pct_asian_2017 pct_other_2017" 			""		 "Table 3b" 	"nstd"	"samp_qual"
		gaps_by_race "ECERS_avg-ECERS_structure CLASS_avg-CLASS_I"															""		 "Table 4b" 	"std"   "samp_qual"
		gaps_by_race "DOE DOE_k12 DOE_pk NYCEEC full_day half_day seats dual_lang enh_lang income_req  meals-late_pickup " 	""		 "Table 6b" 	"nstd"  "samp_qual"
	
	
	//Table 5 - Quality by demographic composition
	***********************************************
		cap program drop qual_regs
		program define qual_regs
			args dv title samp
		
			use "${anlys}/provider-level_SL", clear
			
			gl race "pr_black_2017 pr_hisp_2017 pr_asian_2017 pr_other_2017"

			estimates clear
			
			xi: reg `dv' $race  									[aw=enrollment_2017] if `samp'==1, r
			estimates store x1

			xi: reg `dv' $race i.district 							[aw=enrollment_2017] if `samp'==1, cl(district)
			estimates store x2
		
			xi: reg `dv' $race i.tractnum 							[aw=enrollment_2017] if `samp'==1, cl(tractnum)
			estimates store x3
		
			xi: reg `dv' $race i.tractnum income_req 				[aw=enrollment_2017] if `samp'==1, cl(tractnum)
			estimates store x4
			
			xi: reg `dv' $race i.tractnum income_req DOE DOE_pk 	[aw=enrollment_2017] if `samp'==1, cl(tractnum)
			estimates store x5
			
			estout * using "${output}/Tables/quality regressions `title' `samp'.txt", ///
					cell("b(fmt(2)) _star" se(fmt(2) par(`"="("' `")""'))) keep($race income_req DOE DOE_pk) stats(N) replace
				
		end //ends program qual_regs
		
		//Overall quality
		qual_regs ECERS_avg_z 	"Table 5a (ECERS avg)" "samp_2017"
		qual_regs CLASS_avg_z 	"Table 5b (CLASS avg)" "samp_2017"
		
		qual_regs ECERS_avg_z 	"Table 5a (ECERS avg)" "samp_qual"
		qual_regs CLASS_avg_z 	"Table 5b (CLASS avg)" "samp_qual"
		
	

		
	// Table 7
	****************
	//gl race "pct_black_u5 pct_hisp_u5 pct_asian_u5 pct_other_u5"
	gl race "pct_black pct_hisp pct_asian pct_other"
	
	cap program drop supply_ests
	program supply_ests
		args dv title cond
	
		use "${anlys}/tract-level-supply_SL", clear

		foreach x in black hisp asian other		{
			replace pct_`x'_u5 = pct_`x'_u5 / 100
			replace pct_`x' = pct_`x' / 100
		}
		
		estimates clear

		di "`dv'"
		
		//.25 miles
		
		*any
		xi: logit any_`dv'_p25 area popden $race SES i.borough	`cond', cl(borough)
		margins, dydx($race SES) post
		estimates store est1_`dv'
		
		xi: logit any_`dv'_p25 area popden $race SES i.school_dis	`cond', cl(school_dis)
		margins, dydx($race SES) post
		estimates store est2_`dv'
		
		
		*ECERS
		xi: logit any_HIECERS75_`dv'_p25 area popden $race SES i.borough `cond', cl(borough)
		margins, dydx($race SES) post
		estimates store est3_`dv'
		
		xi: logit any_HIECERS75_`dv'_p25 area popden $race SES i.school_dis `cond', cl(school_dis)
		margins, dydx($race SES) post
		estimates store est4_`dv'
		
		
		*CLASS
		xi: logit any_HICLASS75_`dv'_p25 area popden $race SES i.borough `cond', cl(borough)
		margins, dydx($race SES) post
		estimates store est5_`dv'
		
		
		xi: logit any_HICLASS75_`dv'_p25 area popden $race SES i.school_dis `cond', cl(school_dis)
		margins, dydx($race SES) post
		estimates store est6_`dv'
		
		
		//.5 miles
		
		*any
		xi: logit any_`dv'_p5 area popden $race SES i.borough	`cond', cl(borough)
		margins, dydx($race SES) post
		estimates store est7_`dv'
		
		xi: logit any_`dv'_p5 area popden $race SES i.school_dis	`cond', cl(school_dis)
		margins, dydx($race SES) post
		estimates store est8_`dv'
		
		
		*ECERS
		xi: logit any_HIECERS75_`dv'_p5 area popden $race SES i.borough	`cond', cl(borough)
		margins, dydx($race SES) post
		estimates store est9_`dv'

		
		xi: logit any_HIECERS75_`dv'_p5 area popden $race SES i.school_dis	`cond', cl(school_dis)
		margins, dydx($race SES) post
		estimates store est10_`dv'
		
		
		*CLASS
		xi: logit any_HICLASS75_`dv'_p5 area popden $race SES i.borough	`cond', cl(borough)
		margins, dydx($race SES) post
		estimates store est11_`dv'

		xi: logit any_HICLASS75_`dv'_p5 area popden $race SES i.school_dis	`cond', cl(school_dis)
		margins, dydx($race SES) post
		estimates store est12_`dv'
		
		estout * using "${output}/Tables/`title'.txt", ///
			cell("b(fmt(2)) _star" se(fmt(2) par(`"="("' `")""'))) keep($race SES) stats(N) replace   
			
	end //ends program supply_ests
	
	supply_ests "UPK" 	"Table 7 - any supply "
	
	supply_ests "UPK" 	"Table 7 - (weighted) "  
	
	supply_ests "UPK" 	"T7 - Bronx" 			`"if borough == "Bronx""'
	supply_ests "UPK" 	"T7 - Brooklyn" 		`"if borough == "Brooklyn""'
	supply_ests "UPK" 	"T7 - Manhattan" 		`"if borough == "Manhattan""'
	supply_ests "UPK" 	"T7 - Queens" 			`"if borough == "Queens""'
	supply_ests "UPK" 	"T7 - Staten Island" 	`"if borough == "Staten Island""'
	
	
	
	supply_ests "no_inc" 	"Table 7 plus income" //No difference between results here and those for all providers
												  //Results for HQ providers very similar to those for full sample HQ provs
	
	
	
	//Figure 1
	***************	
	
		cap program drop borough_qual
		program borough_qual
			args chlorovar qual boro aspect 
		
			loc point_data "${anlys}/provider-level_SL"
			loc map_options "id(id) osize(vthin) ocolor(gs10) mocolor(black) mosize(medium) freestyle aspectratio(`aspect') yscale(off) xscale(off) ylabel(, nogrid) legend(title(% black, size(small)))"
			loc chlor_options "clmeth(custom) clbreaks(0 10 20 30 40 50 60 70 80 100) ndpattern(dot)"
			loc point_options "xcoord(longitude) ycoord(latitude) size(medsmall) ocolor(black) fcolor(white) " 
			
			cd "${output}/Figures"
			use "${anlys}/mapping_latlong-data_SL", clear
			
			preserve
			
				keep if borough=="`boro'"
			
				ineq `chlorovar', gendis(dissim)
				sum dissim
				loc disval: di %4.3f r(mean)
			
				spmap `chlorovar' using "${anlys}/mapping_latlong-coord_SL" if boro =="`boro'", title("Bottom `qual' quintile") `map_options' `chlor_options'  ///
					point(data("`point_data'") select(keep if samp_2017==1 & boro =="`boro'" & `qual'_quint==0) `point_options') saving(gph1.gph, replace)
					
				spmap `chlorovar' using "${anlys}/mapping_latlong-coord_SL" if boro =="`boro'", title("Top `qual' quintile") `map_options' `chlor_options'   ///
					point(data("`point_data'") select(keep if samp_2017==1 & boro =="`boro'" & `qual'_quint==4) `point_options') saving(gph2.gph, replace)

				grc1leg gph1.gph gph2.gph, /*title("`boro'") */ ring(1) pos(9) //note("Black-white dissimilarity index for `boro': `disval'", ring(0))
				
				graph export "Figure 2 `boro' `qual'.png", replace

			restore
			
		end //ends program borough_qual
		
		borough_qual pct_black_u5	"ECERS" "Brooklyn" 			"1.25" //Figure 1
		borough_qual pct_black_u5 	"ECERS" "Bronx"				"1.25"
		borough_qual pct_black_u5 	"ECERS" "Queens"			"1.25"
		borough_qual pct_black_u5 	"ECERS" "Manhattan"			"2"
		borough_qual pct_black_u5 	"ECERS" "Staten Island"		"1"
		
	
		borough_qual pct_black_u5	"CLASS" "Brooklyn" 			"1.25" //Figure 1
		borough_qual pct_black_u5 	"CLASS" "Bronx"				"1.25"
		borough_qual pct_black_u5 	"CLASS" "Queens"			"1.25"
		borough_qual pct_black_u5 	"CLASS" "Manhattan"			"2"
		borough_qual pct_black_u5 	"CLASS" "Staten Island"		"1"
		
	//Appendix A - UPK vs. private providers
	********************************************
				
		cap program drop pubvpriv
		program pubvpriv
			args boro aspect title
				
			loc point_data "${anlys}/mapping_point-locations_SL"
			loc map_opts "freestyle aspectratio(`aspect') yscale(off) xscale(off) ylabel(, nogrid) osize(vthin) ocolor(gs10)"
			loc chlor_opts "clmeth(custom) clbreaks(0 10 20 30 40 50 60 70 80 100) ndpattern(dot)"
			loc point_opts "xcoord(longitude) ycoord(latitude) size(small) ocolor(black) fcolor(white) " 

			cd "${output}/Figures"
			use "${anlys}/mapping_latlong-data_SL", clear
			
			spmap pct_black_u5 using "${anlys}/mapping_latlong-coord_SL" if boro=="`boro'", `map_opts' `chlor_opts' id(id)  title("UPK providers")  ///
				point(data("`point_data'") select(keep if samp_2017==1 & UPK==1 & boro=="`boro'") `point_opts' ) /// 
				legend(pos(10) ring(1) title(% black, size(med)))
			graph save "1", replace
			
			spmap pct_black_u5 using "${anlys}/mapping_latlong-coord_SL" if boro=="`boro'", `map_opts' `chlor_opts' id(id) title("Private providers")  ///
				point(data("`point_data'") select(keep if samp_2017==1 & UPK==0 & boro=="`boro'") `point_opts') /// 
				legend(off)
			graph save "2", replace	
			
			grc1leg 1.gph 2.gph, pos(9)
			graph export "Appendix A. UPK vs. private - `boro'.png", replace
		
		end //ends program pubvpriv
	
		pubvpriv 	"Manhattan" 		2
		pubvpriv 	"Queens" 			1.25
		pubvpriv 	"Brooklyn" 			1.25
		pubvpriv 	"Bronx" 			1.25
		pubvpriv 	"Staten Island" 	1
		
	
	/*	
	//Pictures that match Table 1	- out of date, need to update data files if I want it to work
		use "${gen}/attendance by race X boro (for graphing)", clear //This file needs to be created above in Table 1
		
		graph bar (mean) pct_all pct_wh pct_bl pct_hi pct_as if boro_id>1, ///
			by(boro_id /*, title("2017 UPK attendance, by race/ethnicity & borough") */) legend(order(1 "All kids" 2 "White" 3 "Black" 4 "Hispanic" 5 "Asian")) ///
			ytit("% of 4 year olds attending UPK") 
			
		graph export "${output}\Figures\UPK attendance by race X boro.png", replace
	
		gen id = 1
		loc vars "pct_all pct_wh pct_bl pct_hi pct_as"
		
		keep id boronum `vars'
		reshape wide `vars', i(id) j(boronum)
		
		foreach x in all bl wh hi as	{
			rename *`x'? *?`x'
		}
		
		reshape long pct_1 pct_2 pct_3 pct_4 pct_5 pct_6, i(id) j(race) string
		
		gen race_id = 1 		if race == "all"
		replace race_id = 2 	if race == "wh"
		replace race_id = 3		if race == "bl"
		replace race_id = 4 	if race == "hi"
		replace race_id = 5 	if race == "as"
		
		label define races 1 "All kids" 2 "White" 3 "Black" 4 "Hispanic" 5 "Asian"
		label values race_id races
		
		
		graph bar (mean) pct*, by(race_id, title("2017 UPK attendance, by race/ethnicity & borough"))	///
			legend(order(1 "All NYC" 2 "Bronx" 3 "Brooklyn" 4 "Manhattan" 5 "Queens" 6 "Staten Island")) ///
			ytit("% of 4 year olds attending UPK") 
		
		graph export "${output}\Figures\UPK attendance by race X boro (2).png", replace
*/


* Appendix tables/figures
****************************

use "${anlys}/provider-level_SL", clear

corr ECERS_avg CLASS_avg
corr ECERS_avg-ECERS_structure CLASS_avg-CLASS_I
