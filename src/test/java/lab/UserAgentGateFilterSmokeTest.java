package lab;

import java.lang.reflect.Proxy;
import java.util.Collections;
import java.util.Enumeration;
import java.util.List;
import javax.servlet.FilterConfig;
import javax.servlet.ServletContext;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

public final class UserAgentGateFilterSmokeTest {
    private static final String ALLOWED = "BW-SJKIM940708";

    public static void main(String[] args) throws Exception {
        UserAgentGateFilter filter = new UserAgentGateFilter();
        filter.init(new FilterConfig() {
            public String getFilterName() { return "userAgentGate"; }
            public ServletContext getServletContext() { return null; }
            public String getInitParameter(String name) {
                return "allowedUserAgent".equals(name) ? ALLOWED : null;
            }
            public Enumeration<String> getInitParameterNames() {
                return Collections.enumeration(List.of("allowedUserAgent"));
            }
        });

        check(filter, List.of(), false);
        check(filter, List.of("ordinary-browser"), false);
        check(filter, List.of(ALLOWED.toLowerCase()), false);
        check(filter, List.of(ALLOWED, ALLOWED), false);
        check(filter, List.of(ALLOWED), true);
        System.out.println("PASS: missing, wrong, changed-case, duplicate, exact User-Agent");
    }

    private static void check(UserAgentGateFilter filter, List<String> headers, boolean shouldAllow)
            throws Exception {
        int[] status = {0};
        int[] chained = {0};
        HttpServletRequest request = (HttpServletRequest) Proxy.newProxyInstance(
                HttpServletRequest.class.getClassLoader(), new Class<?>[] {HttpServletRequest.class},
                (proxy, method, args) -> "getHeaders".equals(method.getName())
                        ? Collections.enumeration(headers) : null);
        HttpServletResponse response = (HttpServletResponse) Proxy.newProxyInstance(
                HttpServletResponse.class.getClassLoader(), new Class<?>[] {HttpServletResponse.class},
                (proxy, method, args) -> {
                    if ("sendError".equals(method.getName())) status[0] = (Integer) args[0];
                    return null;
                });
        filter.doFilter(request, response, (req, res) -> chained[0]++);
        if (shouldAllow ? chained[0] != 1 || status[0] != 0
                : chained[0] != 0 || status[0] != 403) {
            throw new AssertionError("Unexpected result for headers=" + headers
                    + ", chained=" + chained[0] + ", status=" + status[0]);
        }
    }
}
