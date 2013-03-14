.PHONY=distri
PROJECT=pg_backup_ctl
FILES=pg_backup_ctl README man
PG_BACKUP_CTL_VERSION=0.6


distribution: ${FILES}
	mkdir -p ${PROJECT}-${PG_BACKUP_CTL_VERSION}
	cp -vr ${FILES} ${PROJECT}-${PG_BACKUP_CTL_VERSION}
	sed -i s/@@VERSION@@/${PG_BACKUP_CTL_VERSION}/g ${PROJECT}-${PG_BACKUP_CTL_VERSION}/pg_backup_ctl
	tar -cvjf ${PROJECT}-${PG_BACKUP_CTL_VERSION}.tar.bz2 ${PROJECT}-${PG_BACKUP_CTL_VERSION}
	rm -rf ${PROJECT}-${PG_BACKUP_CTL_VERSION}

clean:
	rm -f *~
	rm -f *.*~
	rm -rf ${PROJECT}-${PG_BACKUP_CTL_VERSION}.tar.bz2
