#!/bin/bash
#SBATCH --time=03:59:00
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=j.p.m.aerts@tudelft.nl

module load cdo
module load nco

# Set working directory and filenames
wd_era5=/lustre1/0/wtrcycle/ERA-5/raw/
wd_preprocess=/nfs/home6/jaerts/wflow_preprocessing/
cd $wd_preprocess

# Set DEM and Orography files for downscaling
local_dem=/nfs/home6/jaerts/wflow_preprocessing/wflow_dem_7050014930_3km.nc
src_orography=/lustre1/0/wtrcycle/ERA-5/raw/era5_orography_2000.nc

# Reduce source orography to a single time-independent field
cdo seltimestep,1 $src_orography src_orography_one_timestep.nc
ncwa -a time src_orography_one_timestep.nc src_orography.nc
rm src_orography_one_timestep.nc

# Set grid for src_orography.nc
ncatted -a coordinates,z,c,c,"lonlat" src_orography.nc

# Extract grid information for remapping and clipping
cdo griddes $local_dem > grid.txt

xsize=`awk '/xsize/ {print $3}' grid.txt`
xfirst=`awk '/xfirst/ {print $3}' grid.txt`
xinc=`awk '/xinc/ {print $3}' grid.txt`
ysize=`awk '/ysize/ {print $3}' grid.txt`
yfirst=`awk '/yfirst/ {print $3}' grid.txt`
yinc=`awk '/yinc/ {print $3}' grid.txt`

xlast=`echo $xfirst $xsize $xinc | awk '{printf "%.15g",$1+$2*$3}'`
ylast=`echo $yfirst $ysize $yinc | awk '{printf "%.15g",$1+$2*$3}'`
lon_min=`echo $xfirst | awk '{printf "%.0f",$1-0.5}'`
lon_max=`echo $xlast  | awk '{printf "%.0f",$1+0.5}'`
lat_min=`echo $yfirst | awk '{printf "%.0f",$1-0.5}'`
lat_max=`echo $ylast  | awk '{printf "%.0f",$1+0.5}'`

# clip source data to bounding box of local model
cdo sellonlatbox,$lon_min,$lon_max,$lat_min,$lat_max src_orography.nc src_orography_clip.nc

# loop over all years to process the datasets per year
startyear=2000
endyear=2018
for year in $(seq $startyear $endyear)
do
	echo
	echo Processing year $year ...
        src_temperature=$wd_era5/era5_2m_temperature_$year.nc
        src_evaporation=$wd_era5/era5_evaporation_$year.nc
        src_precipitation=$wd_era5/era5_total_precipitation_$year.nc
        
        . ./preprocess_era5_wflow_sbm_7050014930_3km_year.sh
done
rm src_orography.nc src_orography_clip.nc grid.txt

# concatenate all years
cdo cat local_forcing_*.nc wflow_local_forcing_ERA5_7050014930_3km_2000_2018.nc
rm local_forcing_*.nc

