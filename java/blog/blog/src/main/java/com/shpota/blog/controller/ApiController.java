package com.shpota.blog.controller;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.shpota.blog.model.BlogRepository;
import com.shpota.blog.model.Post;
import com.shpota.blog.model.jdbc.JdbcBlogRepository;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import javax.naming.Context;
import javax.naming.InitialContext;
import javax.naming.NamingException;
import javax.sql.DataSource;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.List;

/**
 * Minimal JSON API so the UI can be implemented with AJAX or a React SPA.
 *
 * Endpoints:
 *  GET    /api/posts           -> list posts
 *  GET    /api/posts/{id}      -> single post
 *  POST   /api/posts           -> create post   (JSON: {"title":"..","postedText":".."})
 *  PUT    /api/posts/{id}      -> update post   (JSON: {"title":"..","postedText":".."})
 *  DELETE /api/posts/{id}      -> delete post
 */
@WebServlet(name = "ApiController", urlPatterns = {"/api/posts/*"})
public class ApiController extends HttpServlet {
    private static final Logger LOGGER = LogManager.getLogger(ApiController.class);

    private final ObjectMapper objectMapper = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    private BlogRepository repository;

    public static class PostRequest {
        public String title;
        public String postedText;

        public PostRequest() {}
    }

    @Override
    public void init() throws ServletException {
        try {
            Context initContext = new InitialContext();
            DataSource dataSource = (DataSource) initContext.lookup("java:/comp/env/jdbc/postgres");
            this.repository = new JdbcBlogRepository(dataSource);
            LOGGER.info("API ready (DataSource via JNDI): {}", dataSource);
        } catch (NamingException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setCharacterEncoding(StandardCharsets.UTF_8.name());
        resp.setContentType("application/json");

        Integer id = parseId(req);
        if (id == null) {
            List<Post> posts = repository.getAllPost();
            resp.getWriter().write(objectMapper.writeValueAsString(posts));
            return;
        }

        Post post = repository.getPost(id);
        if (post == null) {
            resp.setStatus(HttpServletResponse.SC_NOT_FOUND);
            resp.getWriter().write("{\"error\":\"not found\"}");
            return;
        }
        resp.getWriter().write(objectMapper.writeValueAsString(post));
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        PostRequest body = readBody(req);
        if (body.title == null || body.title.isBlank() || body.postedText == null || body.postedText.isBlank()) {
            resp.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            resp.getWriter().write("{\"error\":\"title and postedText are required\"}");
            return;
        }

        Post post = new Post(body.title, OffsetDateTime.now(), body.postedText);
        int id = repository.addPost(post);

        resp.setCharacterEncoding(StandardCharsets.UTF_8.name());
        resp.setContentType("application/json");
        resp.getWriter().write("{\"postId\":" + id + "}");
    }

    @Override
    protected void doPut(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        Integer id = parseId(req);
        if (id == null) {
            resp.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            resp.getWriter().write("{\"error\":\"missing post id\"}");
            return;
        }

        Post existing = repository.getPost(id);
        if (existing == null) {
            resp.setStatus(HttpServletResponse.SC_NOT_FOUND);
            resp.getWriter().write("{\"error\":\"not found\"}");
            return;
        }

        PostRequest body = readBody(req);
        if (body.title != null && !body.title.isBlank()) {
            existing.setTitle(body.title);
        }
        if (body.postedText != null && !body.postedText.isBlank()) {
            existing.setPostedText(body.postedText);
        }

        repository.updatePost(id, existing);
        resp.setStatus(HttpServletResponse.SC_NO_CONTENT);
    }

    @Override
    protected void doDelete(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        Integer id = parseId(req);
        if (id == null) {
            resp.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            resp.getWriter().write("{\"error\":\"missing post id\"}");
            return;
        }
        repository.deletePost(id);
        resp.setStatus(HttpServletResponse.SC_NO_CONTENT);
    }

    private Integer parseId(HttpServletRequest req) {
        String pathInfo = req.getPathInfo(); // e.g. /123
        if (pathInfo == null || pathInfo.equals("/") || pathInfo.isBlank()) {
            return null;
        }
        String s = pathInfo.startsWith("/") ? pathInfo.substring(1) : pathInfo;
        if (s.isBlank()) return null;
        try {
            return Integer.parseInt(s);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private PostRequest readBody(HttpServletRequest req) throws IOException {
        String json = req.getReader().lines().reduce("", (a, b) -> a + b);
        try {
            return objectMapper.readValue(json, PostRequest.class);
        } catch (JsonProcessingException e) {
            LOGGER.warn("Invalid JSON body: {}", json);
            PostRequest pr = new PostRequest();
            pr.title = null;
            pr.postedText = null;
            return pr;
        }
    }
}
