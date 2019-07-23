# Resample hourly to daily data
cdo -b 32 -daymean $src_temperature temperature_day_temp.nc
cdo -b 32 -daysum $src_evaporation evaporation_day_temp.nc
cdo -b 32 -daysum $src_precipitation precipitation_day_temp.nc

# Set Time to midnight
cdo settime,00:00:00 temperature_day_temp.nc temperature_day_temp2.nc
cdo settime,00:00:00 evaporation_day_temp.nc evaporation_day_temp2.nc
cdo settime,00:00:00 precipitation_day_temp.nc precipitation_day_temp2.nc

# clip source data to bounding box of local model
cdo sellonlatbox,$lon_min,$lon_max,$lat_min,$lat_max temperature_day_temp2.nc   src_2m_temperature_clip.nc
cdo sellonlatbox,$lon_min,$lon_max,$lat_min,$lat_max evaporation_day_temp2.nc   src_evaporation_clip.nc
cdo sellonlatbox,$lon_min,$lon_max,$lat_min,$lat_max precipitation_day_temp2.nc src_precipitation_clip.nc
#cdo sellonlatbox,$lon_min,$lon_max,$lat_min,$lat_max -daysum $src_precipitation_hr src_precipitation_clip.nc

rm temperature_day_temp.nc temperature_day_temp2.nc
rm evaporation_day_temp.nc evaporation_day_temp2.nc
rm precipitation_day_temp.nc precipitation_day_temp2.nc

# derive elevation from geopotential height by dividing by gravity
# units of z will be wrong!
cdo -b 32 divc,9.80665 src_orography_clip.nc src_dem_clip.nc

# derive temperature change associated with elevation change source dataset
# conversion factor is 6.5 K/km
cdo -b 32 mulc,0.0065 src_dem_clip.nc src_dtemp_clip.nc
rm src_dem_clip.nc

# derive temperature change associated with elevation change target dataset
cdo -b 32 mulc,0.0065 $local_dem local_dtemp.nc

# convert temperature from dem elevation to sea level on source grid
cdo merge src_dtemp_clip.nc src_2m_temperature_clip.nc src_temp_dtemp_combined.nc
cdo aexpr,"t2m_sea=z+t2m" src_temp_dtemp_combined.nc src_sl_temperature_clip.nc
rm src_dtemp_clip.nc src_2m_temperature_clip.nc src_temp_dtemp_combined.nc

# downscaling of variables from source grid to local grid
cdo remapdis,grid.txt src_sl_temperature_clip.nc local_sl_temperature.nc
cdo remapdis,grid.txt src_evaporation_clip.nc local_evaporation.nc
cdo remapdis,grid.txt src_precipitation_clip.nc local_precipitation.nc
rm src_sl_temperature_clip.nc src_evaporation_clip.nc src_precipitation_clip.nc

# convert temperature at sea level to temperature at dem elevation on local grid
# Note: includes conversion from Kelvin to Celsius!
cdo merge local_sl_temperature.nc local_dtemp.nc local_temp_dtemp_combined.nc
cdo aexpr,"t2m_down=t2m_sea-Band1-273.15" local_temp_dtemp_combined.nc local_2m_temperature_temp.nc
rm local_sl_temperature.nc local_dtemp.nc local_temp_dtemp_combined.nc

# clean up temperature file contents
cdo delname,t2m,z,Band1,t2m_sea local_2m_temperature_temp.nc local_2m_temperature_temp2.nc
cdo chname,t2m_down,t2m local_2m_temperature_temp2.nc local_2m_temperature_$year.nc
rm local_2m_temperature_temp.nc local_2m_temperature_temp2.nc

# convert negative evaporation in m to positive evaporation in mm
cdo -b 32 mulc,-1000 local_evaporation.nc local_evaporation_mm_$year.nc
rm local_evaporation.nc

# convert negative precipitation in m to positive precipitation in mm
cdo -b 32 mulc,1000 local_precipitation.nc local_precipitation_mm_$year.nc
rm local_precipitation.nc

# merge all quantities into one file
cdo merge local_2m_temperature_$year.nc local_evaporation_mm_$year.nc local_precipitation_mm_$year.nc local_forcing_$year.nc
rm local_2m_temperature.nc local_evaporation_mm.nc local_precipitation_mm.nc
