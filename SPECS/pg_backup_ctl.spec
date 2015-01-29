%global toolname pg_backup_ctl

Summary: Script to manage online backups with PostgreSQL
Name:    %{toolname}
BuildArch: noarch
Version: 0.7
Release: 0%{?dist}
License: GPLv3
Group:   Applications/Databases
URL:     http://www.credativ.de
Source0: %{toolname}-%{version}.tar.bz2
BuildRoot: %{_tmppath}/%{toolname}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires: postgresql >= 8.3
Conflicts: pg_backup_ctl <= 0.1

%description

Script to manage and perform online backups with PostgreSQL databases.

%prep
%setup -n %{toolname}-%{version}
%build

%install

install -d %{buildroot}/%{_bindir}/
install -d %{buildroot}/%{_docdir}/%{toolname}
install -m 0755 pg_backup_ctl %{buildroot}/%{_bindir}/
install -m 644  README        %{buildroot}%{_docdir}/%{toolname}/
install -d %{buildroot}%{_sysconfdir}/bash_completion.d/
install -m 644  pg-backup-ctl.bash-completion %{buildroot}%{_sysconfdir}/bash_completion.d/

%clean
rm -rf %{buildroot}

%post

%preun
%postun

%files
%defattr(-,root,root,-)
%{_bindir}/pg_backup_ctl
%{_docdir}/%{toolname}/README
%{_sysconfdir}/bash_completion.d/

%changelog
* Fri Jan 23 2015 Bernd Helmle <bernd.helmle@credativ.de>
- Update to new upstream release 0.7
- Support streamed basebackups via pg_basebackup
- Support for tablespaces via streamed basebackups
* Fri Dec 2 2011 Bernd Helmle <bernd.helmle@credativ.de>
- Teach do_ls() to use backup history file from the transaction log archive.
- Introduce new commands create-lvmsnapshot and remove-lvmsnapshot.
* Fri Jun  3 2011 Bernd Helmle <bernd.helmle@credativ.de>
- Fix lock file location to be forced to archivedir, since 
  /var/lock is not writeable by daemons on SLES11.
- Fix lookup for zipped XLOG files. This could lead to report
  missing XLOG files even when they are actually present in the archive.
* Tue May 26 2011 Bernd Helmle <bernd.helmle@credativ.de>
- Initial RPM for pg_backup_ctl 0.2
