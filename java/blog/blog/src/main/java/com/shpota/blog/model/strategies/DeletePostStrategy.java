package com.shpota.blog.model.strategies;

import com.shpota.blog.model.BlogRepository;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;

public class DeletePostStrategy extends Strategy {
    public DeletePostStrategy(BlogRepository repository) {
        super(repository);
    }

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        int postId = extractId(request);
        repository.deletePost(postId);
        response.sendRedirect("/posts");
    }

    private int extractId(HttpServletRequest request) {
        String uri = request.getRequestURI();
        String postIdString = uri.replace("/posts/", "")
                .replace("/delete", "");
        return Integer.parseInt(postIdString);
    }
}