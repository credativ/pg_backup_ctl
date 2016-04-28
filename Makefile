PROJECT = pg_backup_ctl
PG_BACKUP_CTL_VERSION = 0.8

FILES = Makefile pg_backup_ctl pg_backup_ctl.1 pg_backup_ctl.md README pg-backup-ctl.bash-completion
PREFIX = /usr

all: pg_backup_ctl.1
	sed -i "s/^## Version: .*/## Version: ${PG_BACKUP_CTL_VERSION}/g" pg_backup_ctl

pg_backup_ctl.1: pg_backup_ctl.md
	pandoc -s -t man -o $@ $^

install: pg_backup_ctl.1
	install -d $(DESTDIR)$(PREFIX)/bin
	install pg_backup_ctl $(DESTDIR)$(PREFIX)/bin
	install -d $(DESTDIR)$(PREFIX)/share/man/man1
	install -m644 pg_backup_ctl.1 $(DESTDIR)$(PREFIX)/share/man/man1

distribution: ${FILES}
	mkdir -p ${PROJECT}-${PG_BACKUP_CTL_VERSION}
	cp -vr ${FILES} ${PROJECT}-${PG_BACKUP_CTL_VERSION}
	tar -cvjf ${PROJECT}-${PG_BACKUP_CTL_VERSION}.tar.bz2 ${PROJECT}-${PG_BACKUP_CTL_VERSION}
	rm -rf ${PROJECT}-${PG_BACKUP_CTL_VERSION}

origtar: distribution
	rm -f ../pg-backup-ctl_${PG_BACKUP_CTL_VERSION}.orig.tar.bz2
	ln ${PROJECT}-${PG_BACKUP_CTL_VERSION}.tar.bz2 ../pg-backup-ctl_${PG_BACKUP_CTL_VERSION}.orig.tar.bz2

clean:
	rm -f *~
	rm -rf ${PROJECT}-${PG_BACKUP_CTL_VERSION}
	rm -f ${PROJECT}-${PG_BACKUP_CTL_VERSION}.tar.bz2

.PHONY: distribution
