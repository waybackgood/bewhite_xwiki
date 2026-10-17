package lab;

import java.io.IOException;
import java.util.Enumeration;
import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/** A lab-only, exact User-Agent gate for the XWiki servlet application. */
public final class UserAgentGateFilter implements Filter {
    private String allowedUserAgent;

    @Override
    public void init(FilterConfig config) throws ServletException {
        String value = config.getInitParameter("allowedUserAgent");
        if (value == null || value.isEmpty()) {
            throw new ServletException("allowedUserAgent must be configured");
        }
        this.allowedUserAgent = value;
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        if (!(request instanceof HttpServletRequest) || !(response instanceof HttpServletResponse)) {
            throw new ServletException("HTTP request and response required");
        }

        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;
        Enumeration<String> values = httpRequest.getHeaders("User-Agent");
        boolean accepted = values.hasMoreElements()
                && this.allowedUserAgent.equals(values.nextElement())
                && !values.hasMoreElements();

        if (!accepted) {
            httpResponse.sendError(HttpServletResponse.SC_FORBIDDEN);
            return;
        }
        chain.doFilter(request, response);
    }

    @Override
    public void destroy() {
        // Nothing to release.
    }
}
