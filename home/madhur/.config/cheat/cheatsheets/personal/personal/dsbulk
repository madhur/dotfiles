Export the table
    java -jar dsbulk-1.11.0.jar unload -query "select * from f_keyspace.breakup where id=138" 

Import the same table 
    java -jar dsbulk-1.11.0.jar load -url ~/output.csv -k f_keyspace -t lb

