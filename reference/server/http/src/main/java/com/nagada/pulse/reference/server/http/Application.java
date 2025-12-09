package com.nagada.pulse.reference.server.http;

import com.nagada.pulse.reference.server.*;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }

    @Bean
    public EventStore eventStore() {
        return new InMemoryEventStore();
    }

    @Bean
    public OffsetStore offsetStore() {
        return new InMemoryOffsetStore();
    }

    @Bean
    public SyncHandler syncHandler(EventStore eventStore, OffsetStore offsetStore) {
        return new SyncHandler(eventStore, offsetStore);
    }
}
