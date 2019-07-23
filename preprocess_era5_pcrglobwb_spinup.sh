#!/bin/bash
#SBATCH --time=10:00:00
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=j.p.m.aerts@tudelft.nl

module load cdo

# Working Directories (set to Cartesius)
wd_era5=/lustre1/0/wtrcycle/ERA-5/raw/
wd_preproc=/lustre1/0/wtrcycle/lorentz-workshop/pcr-globwb/preprocess_meteo/

any_variable=/lustre1/0/wtrcycle/ERA-5/raw//era5_total_precipitation_1990.nc
# Set Working Directory to ERA-5 files
cd $wd_era5

# Extract grid information for remapping and clipping
cdo griddes $any_variable > $wd_preproc/pcrglobwb_grid.txt

# Change xfirst from 0 to -179.875 in pcrglobwb_grid.txt
sed -i 's/xfirst    = 0/xfirst    = -179.875/g' $wd_preproc/pcrglobwb_grid.txt
# Change yfirst from 90 to 89.875 in pcrglobwb_grid.txt
sed -i 's/yfirst    = 90/yfirst    = 89.875/g' $wd_preproc/pcrglobwb_grid.txt
# Change yrows from 721 to 720 in pcrglobwb_grid.txt
sed -i 's/ysize     = 721/ysize     = 720/g' $wd_preproc/pcrglobwb_grid.txt
# Change gridsize from 1038240 to 1036800 in pcrglobwb_grid.txt
sed -i 's/gridsize  = 1038240/gridsize  = 1036800/g' $wd_preproc/pcrglobwb_grid.txt

# loop over all years to process the datasets per year
startyear=1990
endyear=2018
range=$startyear
range+="_"
range+=$endyear

for year in $(seq $startyear $endyear)
do
	echo
	echo Processing year $year ...
        # Resample hourly to daily data 
        cdo -b 32 -daymean $wd_era5/era5_2m_temperature_$year.nc $wd_preproc/era5_2m_temperature_daytemp_$year.nc
        cdo -b 32 -daysum $wd_era5/era5_total_precipitation_$year.nc $wd_preproc/era5_total_precipitation_daytemp_$year.nc
        # Set the time to 00:00:00
        cdo settime,00:00:00 $wd_preproc/era5_2m_temperature_daytemp_$year.nc $wd_preproc/era5_2m_temperature_day_timetemp_$year.nc
        cdo settime,00:00:00 $wd_preproc/era5_total_precipitation_daytemp_$year.nc $wd_preproc/era5_total_precipitation_day_timetemp_$year.nc
        # Reproject data to correct grid for PCR-GLOBWB, bilinear for T and conservative for P.
        cdo remapbil,$wd_preproc/pcrglobwb_grid.txt $wd_preproc/era5_2m_temperature_day_timetemp_$year.nc $wd_preproc/era5_2m_temperature_day_remap_$year.nc
        cdo remapcon,$wd_preproc/pcrglobwb_grid.txt $wd_preproc/era5_total_precipitation_day_timetemp_$year.nc $wd_preproc/era5_total_precipitation_day_remap_$year.nc
done

# Merge seperate years into single file
cdo -b 32 -mergetime -selvar,t2m $wd_preproc/era5_2m_temperature_day_remap_*.nc $wd_preproc/era5_2m_temperature_day_$range.nc
cdo -b 32 -mergetime -selvar,tp $wd_preproc/era5_total_precipitation_day_remap_*.nc $wd_preproc/era5_total_precipitation_day_$range.nc

# Remove temporary files
rm $wd_preproc/era5_2m_temperature_daytemp_*.nc
rm $wd_preproc/era5_total_precipitation_daytemp_*.nc

rm $wd_preproc/era5_2m_temperature_day_timetemp_*.nc
rm $wd_preproc/era5_total_precipitation_day_timetemp_*.nc

rm $wd_preproc/era5_2m_temperature_day_remap_*.nc
rm $wd_preproc/era5_total_precipitation_day_remap_*.nc

# Create Spinup year for PCR-GLOBWB
# Select Spinup period
startspinyear=1990
endspinyear=2004
spinrange=$startspinyear
spinrange+="/"
spinrange+=$endspinyear

cdo selyear,$spinrange $wd_preproc/era5_2m_temperature_day_$range.nc $wd_preproc/era5_2m_temperature_day_spinup_temp.nc
cdo selyear,$spinrange $wd_preproc/era5_total_precipitation_day_$range.nc $wd_preproc/era5_total_precipitation_day_spinup_temp.nc

# Calculate climatology for selected spinup period
cdo ydayavg $wd_preproc/era5_2m_temperature_day_spinup_temp.nc $wd_preproc/era5_2m_temperature_day_spinup_climatology_temp.nc
cdo ydayavg $wd_preproc/era5_total_precipitation_day_spinup_temp.nc $wd_preproc/era5_total_precipitation_day_spinup_climatology_temp.nc

# Change climatology to the year before the start year
let climatologyyear=$startyear-1

cdo setyear,$climatologyyear $wd_preproc/era5_2m_temperature_day_spinup_climatology_temp.nc $wd_preproc/era5_2m_temperature_day_spinup_climatologyyear.nc
cdo setyear,$climatologyyear $wd_preproc/era5_total_precipitation_day_spinup_climatology_temp.nc $wd_preproc/era5_total_precipitation_day_spinup_climatologyyear.nc

# Merge climatology year with the rest of the dataset
cdo -b 32 -mergetime -selvar,t2m $wd_preproc/era5_2m_temperature_day_spinup_climatologyyear.nc $wd_preproc/era5_2m_temperature_day_$range.nc $wd_preproc/era5_2m_temperature_day_spinup_$range.nc
cdo -b 32 -mergetime -selvar,tp $wd_preproc/era5_total_precipitation_day_spinup_climatologyyear.nc $wd_preproc/era5_total_precipitation_day_$range.nc $wd_preproc/era5_total_precipitation_day_spinup_$range.nc

# Remove temporary files
rm $wd_preproc/era5_2m_temperature_day_spinup_temp.nc
rm $wd_preproc/era5_total_precipitation_day_spinup_temp.nc

rm $wd_preproc/era5_2m_temperature_day_spinup_climatology_temp.nc
rm $wd_preproc/era5_total_precipitation_day_spinup_climatology_temp.nc

rm $wd_preproc/era5_2m_temperature_day_spinup_climatologyyear.nc
rm $wd_preproc/era5_total_precipitation_day_spinup_climatologyyear.nc

# Start PCR-GLOBWB model run
wd_pcrglobwb=/lustre1/0/wtrcycle/lorentz-workshop/pcr-globwb/model_scripts/
wd_pcrglobwb_inifile=/lustre1/0/wtrcycle/lorentz-workshop/pcr-globwb/model_input/RM_05min_Lorentz.ini

cd $wd_pcrglobwb

# Activate .bash_profile Cartesius
source /home/edwinsut/.bashrc3

# Execute model run
python deterministic_runner.py $wd_pcrglobwb_inifile

echo Model run complete


