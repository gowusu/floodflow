# Potential evapotranspiration by the Oudin formula

Computes daily potential evapotranspiration (PET) from air temperature
and latitude alone, following Oudin et al. (2005). Because it needs no
radiation, humidity or wind data, it suits data-scarce settings where
only temperature is available. Extraterrestrial radiation is derived
from solar geometry for the given day of year and latitude.

## Usage

``` r
pet_oudin(jday, temp_c, lat_deg)
```

## Arguments

- jday:

  Integer vector of Julian day of year (1–366).

- temp_c:

  Numeric vector of mean daily air temperature in degrees Celsius, the
  same length as `jday`.

- lat_deg:

  Latitude in decimal degrees (positive north, negative south).

## Value

A numeric vector of PET in millimetres per day, never negative.

## References

Oudin, L. et al. (2005) Which potential evapotranspiration input for a
lumped rainfall-runoff model? Journal of Hydrology 303, 290–306.
[doi:10.1016/j.jhydrol.2004.08.026](https://doi.org/10.1016/j.jhydrol.2004.08.026)

## Examples

``` r
# A year of PET for Accra (latitude ~5.6 N)
jd <- 1:365
temp <- 28 + 3 * sin(2 * pi * (jd - 40) / 365)
pet <- pet_oudin(jd, temp, lat_deg = 5.6)
range(pet)
#> [1] 4.115981 5.472362
```
