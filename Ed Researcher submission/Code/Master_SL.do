/****************************************************
* Purpose: Master do file for NYC pre-k project
* Author: Scott Latham
* Date created: 11/5/2018
* Last modified: 1/22/2019
*****************************************************/

pause on
*gl user "Scott" 	//Laptop
gl user "slatham" 	//Work desktop

gl path 	"C:/Users/${user}/Dropbox/Research/Current_projects/NYC pre-k"
gl prj_path "${path}/Racial disparities in quality"

gl raw 		"${path}/Raw data"
gl inter 	"${prj_path}/Generated data/Intermediate"
gl anlys 	"${prj_path}/Generated data/Analysis"

gl output 	"${prj_path}/Output2"
	

	
//Do files
do "${prj_path}/Code/Import_SL"
do "${prj_path}/Code/Data cleaning_SL"






