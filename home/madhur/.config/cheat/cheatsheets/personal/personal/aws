Delete subnet cache
    aws elasticache delete-cache-subnet-group     --cache-subnet-group-name "e44cf4-mm-jesque" --region ap-south-1

Resize instance
    aws ec2 modify-instance-attribute --instance-id i-06ec57184ffcdac48 --instance-type "{\"Value\": \"c6g.4xlarge\"}"

Start instances
    aws ec2 start-instances --instance-ids i-06ec57184ffcdac48 i-01b8c40caea65ad68 i-06f3837ce59c182b4 i-07445b5bb8a03dc2e i-0d4e276228ec06d0b --region ap-south-1

Delete elasticcache
    aws elasticache delete-replication-group --replication-group-id elasticcache-name  --region ap-south-1
