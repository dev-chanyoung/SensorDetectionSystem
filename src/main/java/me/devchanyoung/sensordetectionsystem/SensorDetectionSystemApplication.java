package me.devchanyoung.sensordetectionsystem;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@SpringBootApplication
public class SensorDetectionSystemApplication {
    public static void main(String[] args) {
        SpringApplication.run(SensorDetectionSystemApplication.class,args);
    }
}
