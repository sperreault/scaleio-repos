scaleio-repos
======================
scaleio-repos is a project to help the creation and management of a local 
repository of ScaleIO related packages of ease of deployment. The current
focus is on YUM (RHEL/CentOS/Fedora), more will be added in the future.

## Description
Since most deployment of ScaleIO are done at scale, managing a local repository
of ScaleIO within your organization makes a lot of sense. It gives you the 
flexibility to help the automation of installations and updates using more
standard tools set like [Ansible](http://www.ansible.org/), [Puppet](http://www.puppet.org/)
and others.

Currently supported platform:
- [YUM](http://yum.baseurl.org/)
  - RHEL/CentOS
  - OEL

## Installation

    $ git clone https://github.com/sperreault/scaleio-repos.git
 
## Usage Instructions

```
$ cd scaleio-repos
$ ./crete-scaleio-repos -d <destdir> -s <sourcezipfile> [-v] 
example
$ ./create-scaleio-repos -d /srv/repos -s ScaleIO_2.0.1.3_Complete_Software_Download.zip
```

## Future
Currently we only support running this in a CentOS host as we rely on the following 
rpm's createrepo, dpkg, dpkg-devel, gnupg2, perl-TimeDate, but we would like to
support also the following:
- Repo server
  - Debian
  - Ubuntu
- Generation of "release" rpm's like [epel](https://fedoraproject.org/wiki/EPEL)
- Clean up the code
  - break out into multiple files

## Contribution
Create a fork of the project into your own reposity. Make all your necessary changes and create a pull request with a description on what was added or removed and details explaining the changes in lines of code. If approved, project owners will merge it.

Licensing
---------

*scaleio-repos* is freely distributed under the [MIT License](https://github.com/sperreault/scaleio-repos/LICENSE "LICENSE"). See LICENSE for details.


Support
-------
Please file bugs and issues on the Github issues page for this project. This is to help keep track and document everything related to this repo. For general discussions and further support you can join the [{code} Community slack channel](http://community.codedellemc.com/). The code and documentation are released with no warranties or SLAs and are intended to be supported through a community driven process.
