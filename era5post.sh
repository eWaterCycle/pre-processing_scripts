#!/usr/bin/env bash
inputDir=$1
outputDir=$2
tmpDir=$3
startyear=$4
endyear=$5

basename="era5_"
ext=".nc"

cdocommand="-f nc4c -szip zip_6"

rm -rf ${tmpDir}
mkdir -p ${tmpDir}

# perform pre-processing
avVar="2m_temperature surface_solar_radiation_downwards"
for var in ${avVar}; do
    for yr in $(seq ${sYear} ${fYear}); do
        cdo ${cdocommand} daymean ${inputDir}/${basename}${var}_${yr}${ext} ${outputDir}/${basename}${var}_${yr}${ext}
    done
done

accVar="evaporation total_precipitation"
for var in ${accVar}; do
    for yr in $(seq ${sYear} ${fYear}); do
        cdo ${cdocommand} daysum -setrtoc,-1e99,0,0 ${inputDir}/${basename}${var}_${yr}${ext} ${outputDir}/${basename}${var}_${yr}${ext}
    done
done

# daily windspeed
u10=10m_u_component_of_wind
v10=10m_v_component_of_wind
for yr in $(seq ${startyear} ${endyear}); do
    cdo merge ${inputDir}/era5_${u10}_${yr}.nc ${inputDir}/era5_${v10}_${yr}.nc ${tmpDir}/uv_${yr}.nc
    cdo -b F32 ${cdocommand} expr,'uvw10=sqrt(u10*u10+v10*v10)' ${tmpDir}/uv_${yr}.nc ${outputDir}/era5_windspeed_${yr}.nc
    rm ${tmpDir}/uv_${yr}.nc
done

# daily minimum and maximum temperature
t2m=2m_temperature
for yr in $(seq ${startyear} ${endyear}); do
    cdo ${cdocommand} daymin ${inputDir}/era5_${t2m}_${yr}.nc ${outputDir}/era5_min_2m_temperature_${yr}.nc
    cdo ${cdocommand} daymax ${inputDir}/era5_${t2m}_${yr}.nc ${outputDir}/era5_min_2m_temperature_${yr}.nc
done

# actual vapour pressure
# calculated from e = 6.11 ×10^(7.5×Td/237.3+Td)
dewp=2m_dewpoint_temperature
for yr in $(seq ${startyear} ${endyear}); do
    cdo -b F32 ${cdocommand} expr,'e=6.11*exp(7.5*(d2m-273.15)/237.3+(d2m-273.15))' ${inputDir}/era5_${dewp}_${yr}.nc ${outputDir}/era5_actual_vapour_pressure_${yr}.nc
done

rm -rf ${tmpDir}

