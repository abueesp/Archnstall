#Relational database management systems (RDBMS) support the relational table-oriented data model (https://db-engines.com/en/article/relational+dbms)
sudo pacman -S mariadb --noconfirm --needed #prefered over oracle, microsoft sql, microsoft access, IBM DB2, SAP Adaptative Server, SAP Hana, microsoft azure, google bigquery, amazon redshift, amazon aurora, 
sudo pacman -S mysql-workbench --noconfirm --needed #prefered over phpmyadmin, heidisql, dbeaver freemium. Adminer is lighter option.
read -p "Write an user for the database (mysql by default):" USERDB
USERDB="${USERDB:=mysql}"
useradd $USERDB
echo "Creating terminal for $USERDB"
sudo chsh -s /bin/bash $USERDB
sudo passwd $USERDB
echo "Open mysqld on a new terminal"
echo "And check the port and the socket"
echo "Edit /etc/mysql/my.cnf, add skip-grant-tables below [mysqld] and configure InnoDB"
echo "Edit and add echo "socket=/run/mysqld/mysqld.sock" >>$config at the make_config() before sed"
echo "Execute mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql"
echo "Execute mysql -u $USERDB -p"
echo "See db and tables with show databases; and show tables;"
su - mysql


#Document stores, also called document-oriented database systems, are characterized by their schema-free organization of data. (https://db-engines.com/en/article/Document+Stores)

#Key-value stores, probably the simplest form of database management systems. They can only store pairs of keys and values, as well as retrieve values when a key is known. (https://db-engines.com/en/article/Key-value+Stores)

#Search engines are NoSQL database management systems dedicated to the search for data content (https://db-engines.com/en/article/Search+Engines)

#Native XML DBMS's (sometimes abbreviated as NXD) are database management systems, whose internal data model corresponds to XML documents.  They can represent hierarchical data, they understand embedded PCDATA declarations in XML elements, and they support XML-specific query languages such as XPath, XQuery or XSLT.  (https://db-engines.com/en/article/Native+XML+DBMS)

#Graph DBMS, also called graph-oriented DBMS or graph database, represent data in graph structures as nodes and edges, which are relationships between nodes. (https://db-engines.com/en/article/Graph+DBMS)

#Resource Description Framework (RDF) dabases have a methodology for the description of information. The RDF model represents information as triples in the form of subject-predicate-object. Specially used in IT resources and Semantic Web (https://db-engines.com/en/article/RDF+Stores)

#Content stores, also called content repositories, are database management systems specialized in the management of digital content, such as text, pictures or videos, including their metadata. (https://db-engines.com/en/article/Content+Stores)

#Time Series DBMS is a database management system that is optimized for handling time series data: each entry is associated with a timestamp. (https://db-engines.com/en/article/Time+Series+DBMS)

#Event stores are database management systems implementing the concept of event sourcing. They persists all state changing events for an object together with a timestamp, thereby creating time series for individual objects. The current state of an object can be inferred by replaying all events for that object from time 0 till the current time.

#Wide column stores, also called extensible record stores, store data in records with an ability to hold very large numbers of dynamic columns. Since the column names as well as the record keys are not fixed, and since a record can have billions of columns, wide column stores can be seen as two-dimensional key-value stores (https://db-engines.com/en/article/Wide+Column+Stores)

#Multivalue DBMS are database management systems, which - similar to relational systems - store data in tables. However, other than RDBMSs, they can assign more than one value to a record's attribute. As this contradicts the first normal form, these systems are sometimes called NF2 (non-first normal form) systems. (https://db-engines.com/en/article/Multivalue+DBMS)

#Navigational DBMS describes a class of database management systems, that allow access to data sets only via linked records. Not widely used. Depending on the flexibility of linking, they are grouped into hierarchical DBMS and network DBMS. (https://db-engines.com/en/article/Navigational+DBMS)

#Object oriented DBMS follows an object oriented data model with classes (the schema of objects), properties and methods. An object is always managed as a whole, without having to introduce complex JOINs if divided on different tables. In recent years, the classic relational database management systems have been extended with some object oriented features, such as user-defined data types and structured attributes; as well as extensions such as  Hibernate or JPA; so they are not the first option anymore. (https://db-engines.com/en/article/Object+oriented+DBMS)
