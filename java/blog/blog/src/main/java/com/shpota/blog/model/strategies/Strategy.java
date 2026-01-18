package com.shpota.blog.model.strategies;

import com.shpota.blog.model.BlogRepository;
import com.shpota.blog.util.Assert;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.format.DateTimeFormatter;

public abstract class Strategy {
    final static DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("uuuu-MM-dd HH:mm");
    final BlogRepository repository;

    Strategy(BlogRepository repository) {
        Assert.notNull(repository, "Repository must not be null.");
        this.repository = repository;
    }

    public abstract void handle(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException;
}