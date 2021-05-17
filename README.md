# nc-variants

Analyze a directory structure containing netcdf files for variance in dimension or variable structure or attributes.

## Options

* `-q` Don't print log messages about progress, just the final output
* `-i` CSV of nco-json fields to ignore, in jq format
       (example `'.variables.time.attributes.units,.attributes.title'`).
       `.attributes.history` is always ignored/
* `-o` Output directory for report generation (default `out`)
* `-t` Occurence percentage threshold below which non-standard values should have their files listed
       in the report (default 50%)

## Example invocation

```
./nc-variants.sh -i .variables.time.attributes.units,.attributes.title,.attributes.NCO ../raw/2021
```

## Docker invocation

```
docker run --rm -v /path/to/some/data/raw/2021:/data:ro registry.axiom/nc-variants \
  ./nc-variants.sh -i .variables.time.attributes.units,.attributes.title,.attributes.NCO /data
```

## Requirements

* conda (create environment from `environment.yml`)
* awk
* sed

## How it works

* `ncks` is used to produce nco-json for each nc file found in the target directory
* `jq` removes any ignored fields
* `md5sum` is used to fingerprint the resulting nco-json, and each variant is recorded
  along with a list of all nc files having that variant
* [`gron`](https://github.com/tomnomnom/gron) is used to flatten the nco-json
  into a greppable, summable format
* `awk` is used to create a wgron ("weighted gron") file for each variant with the number
  of files having that variant as a first column for later summing
* `awk` is used to sum values from all wgron files and calculate the percentage and frequency
  of occurrence of each value
* a final pass is made over the document to add file listings for any non-standard values
  with percentage occurrence below a configurable threshold (default 50%)

## Example output

```
100.0% (31/31) attributes.fileid = "SOUTH CALIFORNIA BIGHT";
100.0% (31/31) attributes.type = "ROMS REAL TIME FORECASTING";
100.0% (31/31) dimensions.depth = 14;
100.0% (31/31) dimensions.lat = 391;
100.0% (31/31) dimensions.lon = 351;
100.0% (31/31) dimensions.time = 73;
100.0% (31/31) variables.depth.attributes.add_offset = 0;
100.0% (31/31) variables.depth.attributes.long_name = "depth";
100.0% (31/31) variables.depth.attributes.scale_factor = 1;
 19.4% ( 6/31) variables.depth.attributes.units = "m";
    ../raw/2021/2021_01/ca_roms_forecast_2021-01-22.nc
    ../raw/2021/2021_01/ca_roms_forecast_2021-01-27.nc
    ../raw/2021/2021_01/ca_roms_forecast_2021-01-28.nc
    ../raw/2021/2021_01/ca_roms_forecast_2021-01-29.nc
    ../raw/2021/2021_01/ca_roms_forecast_2021-01-30.nc
    ../raw/2021/2021_01/ca_roms_forecast_2021-01-31.nc
 80.6% (25/31) variables.depth.attributes.units = "meters";
100.0% (31/31) variables.depth.shape[0] = "depth";
100.0% (31/31) variables.depth.type = "float";
100.0% (31/31) variables.lat.attributes.add_offset = 0;
100.0% (31/31) variables.lat.attributes.long_name = "Latitude";
100.0% (31/31) variables.lat.attributes.modulo = " ";
100.0% (31/31) variables.lat.attributes.scale_factor = 1;
100.0% (31/31) variables.lat.attributes.units = "degrees_north";
100.0% (31/31) variables.lat.shape[0] = "lat";
100.0% (31/31) variables.lat.type = "float";
100.0% (31/31) variables.lon.attributes.add_offset = 0;
100.0% (31/31) variables.lon.attributes.long_name = "Longitude";
100.0% (31/31) variables.lon.attributes.modulo = " ";
100.0% (31/31) variables.lon.attributes.scale_factor = 1;
100.0% (31/31) variables.lon.attributes.units = "degrees_east";
100.0% (31/31) variables.lon.shape[0] = "lon";
100.0% (31/31) variables.lon.type = "float";
100.0% (31/31) variables.salt.attributes.add_offset = 0;
100.0% (31/31) variables.salt.attributes.long_name = "Salinity";
100.0% (31/31) variables.salt.attributes.missing_value = -9999;
100.0% (31/31) variables.salt.attributes.scale_factor = 1;
100.0% (31/31) variables.salt.attributes.units = "ROMS-Unit";
100.0% (31/31) variables.salt.shape[0] = "time";
100.0% (31/31) variables.salt.shape[1] = "depth";
100.0% (31/31) variables.salt.shape[2] = "lat";
100.0% (31/31) variables.salt.shape[3] = "lon";
100.0% (31/31) variables.salt.type = "float";
100.0% (31/31) variables.temp.attributes.add_offset = 0;
100.0% (31/31) variables.temp.attributes.long_name = "Temperature";
100.0% (31/31) variables.temp.attributes.missing_value = -9999;
100.0% (31/31) variables.temp.attributes.scale_factor = 1;
100.0% (31/31) variables.temp.attributes.units = "degrees C";
100.0% (31/31) variables.temp.shape[0] = "time";
100.0% (31/31) variables.temp.shape[1] = "depth";
100.0% (31/31) variables.temp.shape[2] = "lat";
100.0% (31/31) variables.temp.shape[3] = "lon";
100.0% (31/31) variables.temp.type = "float";
 80.6% (25/31) variables.time.attributes.add_offset = 0;
100.0% (31/31) variables.time.attributes.long_name = "time";
 80.6% (25/31) variables.time.attributes.scale_factor = 1;
100.0% (31/31) variables.time.shape[0] = "time";
 80.6% (25/31) variables.time.type = "float";
 19.4% ( 6/31) variables.time.type = "int";
    ../raw/2021/2021_01/ca_roms_forecast_2021-01-22.nc
    ../raw/2021/2021_01/ca_roms_forecast_2021-01-27.nc
    ../raw/2021/2021_01/ca_roms_forecast_2021-01-28.nc
    ../raw/2021/2021_01/ca_roms_forecast_2021-01-29.nc
    ../raw/2021/2021_01/ca_roms_forecast_2021-01-30.nc
    ../raw/2021/2021_01/ca_roms_forecast_2021-01-31.nc
100.0% (31/31) variables.u.attributes.add_offset = 0;
100.0% (31/31) variables.u.attributes.long_name = "Zonal Current";
100.0% (31/31) variables.u.attributes.missing_value = -9999;
100.0% (31/31) variables.u.attributes.scale_factor = 1;
100.0% (31/31) variables.u.attributes.units = "m/s";
100.0% (31/31) variables.u.shape[0] = "time";
100.0% (31/31) variables.u.shape[1] = "depth";
100.0% (31/31) variables.u.shape[2] = "lat";
100.0% (31/31) variables.u.shape[3] = "lon";
100.0% (31/31) variables.u.type = "float";
100.0% (31/31) variables.v.attributes.add_offset = 0;
100.0% (31/31) variables.v.attributes.long_name = "Meridional Current";
100.0% (31/31) variables.v.attributes.missing_value = -9999;
100.0% (31/31) variables.v.attributes.scale_factor = 1;
100.0% (31/31) variables.v.attributes.units = "m/s";
100.0% (31/31) variables.v.shape[0] = "time";
100.0% (31/31) variables.v.shape[1] = "depth";
100.0% (31/31) variables.v.shape[2] = "lat";
100.0% (31/31) variables.v.shape[3] = "lon";
100.0% (31/31) variables.v.type = "float";
100.0% (31/31) variables.zeta.attributes.add_offset = 0;
100.0% (31/31) variables.zeta.attributes.long_name = "Sea Surface Height";
100.0% (31/31) variables.zeta.attributes.missing_value = -9999;
100.0% (31/31) variables.zeta.attributes.scale_factor = 1;
100.0% (31/31) variables.zeta.attributes.units = "m";
100.0% (31/31) variables.zeta.shape[0] = "time";
100.0% (31/31) variables.zeta.shape[1] = "lat";
100.0% (31/31) variables.zeta.shape[2] = "lon";
100.0% (31/31) variables.zeta.type = "float";
```
