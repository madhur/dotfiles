Kafka consumer groups - Find lag
        ./kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group c64e47f7-95fa-4985-a02e-71fa86c2c270 --describe

List all consumer groups
        ./kafka-consumer-groups.sh --bootstrap-server localhost:9092 --all-groups

Consume from topic
        ./kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic auditTopic

Create kafka topics from text file
        cat topics.txt | xargs -I % -L1 sh ~/kafka_2.11-2.2.1/bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --topic % --replication-factor 1 --partitions 1

