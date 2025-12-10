package com.azure.monitoring.lab.api.controller;

import com.azure.monitoring.lab.api.model.Product;
import com.azure.monitoring.lab.api.repository.ProductRepository;
import com.microsoft.applicationinsights.TelemetryClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class ApiController {
    
    private final ProductRepository productRepository;
    private final TelemetryClient telemetryClient;
    
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "monitoring-lab-api");
        response.put("version", "1.0.0");
        return ResponseEntity.ok(response);
    }
    
    @GetMapping("/products")
    @Cacheable(value = "products", unless = "#result == null")
    public ResponseEntity<List<Product>> getAllProducts() {
        log.info("Fetching all products");
        
        // Track custom event in Application Insights
        Map<String, String> properties = new HashMap<>();
        properties.put("operation", "getAllProducts");
        telemetryClient.trackEvent("ProductsRequested", properties, null);
        
        List<Product> products = productRepository.findAll();
        log.info("Found {} products", products.size());
        
        return ResponseEntity.ok(products);
    }
    
    @GetMapping("/products/{id}")
    @Cacheable(value = "product", key = "#id", unless = "#result == null")
    public ResponseEntity<Product> getProduct(@PathVariable Long id) {
        log.info("Fetching product with id: {}", id);
        
        return productRepository.findById(id)
            .map(product -> {
                Map<String, String> properties = new HashMap<>();
                properties.put("productId", id.toString());
                properties.put("productName", product.getName());
                telemetryClient.trackEvent("ProductViewed", properties, null);
                return ResponseEntity.ok(product);
            })
            .orElseGet(() -> {
                log.warn("Product not found: {}", id);
                telemetryClient.trackException(new RuntimeException("Product not found: " + id));
                return ResponseEntity.notFound().build();
            });
    }
    
    @PostMapping("/products")
    public ResponseEntity<Product> createProduct(@RequestBody Product product) {
        log.info("Creating new product: {}", product.getName());
        
        Product savedProduct = productRepository.save(product);
        
        Map<String, String> properties = new HashMap<>();
        properties.put("productId", savedProduct.getId().toString());
        properties.put("productName", savedProduct.getName());
        telemetryClient.trackEvent("ProductCreated", properties, null);
        
        return ResponseEntity.ok(savedProduct);
    }
}
