package com.shpota.blog.model.strategies;

import com.shpota.blog.model.BlogRepository;
import com.shpota.blog.model.Post;
import org.junit.Test;

import jakarta.servlet.RequestDispatcher;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.time.OffsetDateTime;

import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

public class EditPostStrategyTest {
    @Test
    public void shouldHandle() throws Exception {
        BlogRepository repository = mock(BlogRepository.class);
        Strategy strategy = new EditPostStrategy(repository);
        HttpServletRequest request = mock(HttpServletRequest.class);
        HttpServletResponse response = mock(HttpServletResponse.class);
        int postId = 4;
        given(request.getRequestURI()).willReturn("/posts/" + postId + "/edit");
        Post post = new Post("Title", OffsetDateTime.now(), "Posted text");
        given(repository.getPost(4)).willReturn(post);
        RequestDispatcher dispatcher = mock(RequestDispatcher.class);
        given(request.getRequestDispatcher("/edit.jsp")).willReturn(dispatcher);

        strategy.handle(request, response);

        verify(request).setAttribute("post", post);
        verify(dispatcher).forward(request, response);
    }
}