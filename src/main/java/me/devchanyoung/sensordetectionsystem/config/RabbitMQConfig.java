package me.devchanyoung.sensordetectionsystem.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    public static final String EXCHANGE_NAME = "vehicle.exchange";
    public static final String ALERT_QUEUE_NAME = "vehicle.alert.queue";
    public static final String ROUTING_KEY = "vehicle.log.saved";

    // 1. 교환기 생성 (메시지를 적절한 큐로 라우팅)
    @Bean
    public DirectExchange vehicleExchange() {
        return new DirectExchange(EXCHANGE_NAME);
    }

    // 2. 큐 생성 (서버가 죽어도 데이터가 유지되도록 durable = true)
    @Bean
    public Queue alertQueue() {
        return new Queue(ALERT_QUEUE_NAME, true);
    }

    // 3. 교환기와 큐를 라우팅 키로 바인딩 
    @Bean
    public Binding alertBinding(Queue alertQueue, DirectExchange vehicleExchange) {
        return BindingBuilder.bind(alertQueue).to(vehicleExchange).with(ROUTING_KEY);
    }

    // 4. 객체를 JSON 형태로 큐에 직렬화/역직렬화하기 위한 컨버터
    @Bean
    public MessageConverter messageConverter() {
        return new Jackson2JsonMessageConverter();
    }
}