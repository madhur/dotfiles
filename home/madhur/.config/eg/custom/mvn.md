# mvn

Run spring boot application
    mvn spring-boot:run

Run spring boot application with arguments
    mvn spring-boot:run -Dspring-boot.run.arguments=10234

Run specific test
    mvn clean package -Dtest=FootballMatchEndTest

Exclude tests and other stuff
    mvn clean package -DskipTests -Dspotbugs.skip=true -Dcheckstyle.skip=true -Djacoco.skip=true

See dependency tree
    mvn dependency:tree
