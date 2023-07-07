Run a controller
    locust -f fantasy_connection_service/controller/connection_test_controller.py --host localhost:8080 

Run a locust controller as master
    locust -f fantasy_connection_service/controller/kafka_publish_test_controller.py --host localhost:8080 --users 1 --spawn-rate 1 --master

Run a locst controller as worker
    locust -f fantasy_connection_service/controller/kafka_publish_test_controller.py --host localhost:8080 --users 1 --spawn-rate 1 --worker
