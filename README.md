# nc-variants

Analyze a directory structure containing netcdf files for variance in dimension or variable structure or attributes.

Example invocation

```
./nc-variants.sh -i .variables.time.attributes.units,.attributes.title,.attributes.NCO ../raw/2021
```

Docker invocation

```
docker run --rm -v /path/to/some/data/raw/2021:/data registry.axiom/nc-variants ./nc-variants.sh -i .variables.time.attributes.units,.attributes.title,.attributes.NCO /data
```
