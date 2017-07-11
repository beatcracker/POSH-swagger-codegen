# Generate PowerShell module from [OpenAPI](https://www.openapis.org/) spec using [Swagger Codegen](http://swagger.io/swagger-codegen/).

[![Promo Tweet](img/PromoTweet.png)](https://twitter.com/wing328/status/877184938344239104)

Swagger Codegen 2.2.3 aims to have PowerShell module generator. Until it's released, you can build latest version of Swagger Codegen yourself, which already has beta-quality PowerShell support and use it to generate PowerShell module.

## Info

* Discussion: [[PowerShell] Add PowerShell API client generator](https://github.com/swagger-api/swagger-codegen/pull/5789)
* Pull Request: [PowerShell module](https://github.com/swagger-api/swagger-codegen/issues/4320)

# Details

This repository contains set of scripts that will:

* Install [Chocolatey](https://chocolatey.org/)
* Install [JDK](http://www.oracle.com/technetwork/java/javase/downloads/index.html) and [Maven](https://maven.apache.org/)
* Clone Swagger Codegen repo: https://github.com/swagger-api/swagger-codegen  
  You need to have [Git](https://git-scm.com/) installed. Chocolatey can do this for you: `choco install git -params "/GitAndUnixToolsOnPath"`
* Build Swagger Codegen from source using Maven
* Generate PowerShell module using either API name to get OpenAPI spec from [APIs.guru](https://apis.guru/api-doc/) or custom `swagger.json`/`swagger.yml` file.  
   You can view full list of APIs.guru APIs here: https://github.com/APIs-guru/openapi-directory

# Usage

Generated module will be available in the `ApiName\PowerShell\src\IO.Swagger` directory.

To import it use: `Import-Module -name .\ApiName\PowerShell\src\IO.Swagger`

## Build [XKCD](https://xkcd.com/) module

If run without arguments, `Build.ps1` script will install all prerequisites, build Swagger Codegen and generate XKCD module using this spec: https://github.com/APIs-guru/openapi-directory/tree/master/APIs/xkcd.com/1.0.0

* Run PowerShell/PowerShell ISE as admin
* Run `Build.ps1` script

## Build custom module

If you already run `Build.ps1` script and have all prerequisites, you can build custom PowerShell modules.

### By API name

Build `instagram.com` module by API name

```posh
.\Build.ps1 -ApiName instagram.com -SkipInit
```

### From custom file

Build `instagram.com` module from file

```posh
.\Build.ps1 -ApiName instagram.com -InFile .\path\to\spec\swagger.yml -SkipInit
```

# Issues

If you're getting errors about NuGet version, like this one:

```none
The 'Newtonsoft.Json 10.0.3' package requires NuGet client version '2.12' or above,
but the current NuGet version is '2.8.60717.93'.
```

run `.\Build.ps1` with `-FixCSharBuild` parameter.

See this issue in Swagger Codgen repo for details:

* [[CSharp] Can't build client using "build.bat"](https://github.com/swagger-api/swagger-codegen/issues/6022)
