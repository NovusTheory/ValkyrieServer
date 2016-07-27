  server { # Valkyrie Server
    listen 443 ssl;
    server_name $VALKYRIE_NAME;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
    lua_code_cache ${{CODE_CACHE}};

    ssl on;
    ssl_certificate $CERT_ROOT/$CERT_NAME;
    ssl_certificate_key $CERT_ROOT/$CERT_KEY;

    ssl_stapling on;
    ssl_stapling_verify on;

    ssl_session_timeout 1d;

    ssl_trusted_certificate $CERT_ROOT/$TR_CERT;
    ssl_protocols TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:ECDH+3DES:RSA+AES:RSA+3DES:!ADH:!AECDH:!MD5:!DSS;
    ssl_dhparam $DHPARAM;

    location / {
      set $_url "";
      default_type text/html;
      content_by_lua_block {
        require "lfs".chdir(ngx.var.VALKYRIE_NAME);
        require("lapis").serve("app")
      }
    }

    location /static/ {
      alias $VALKYRIE_NAME/static/;
    }

    location /favicon.ico {
      alias $VALKYRIE_NAME/static/favicon.ico;
    }

    location /proxy {
      internal;
      rewrite_by_lua "
        local req = ngx.req

        for k,v in pairs(req.get_headers()) do
          if k ~= 'content-length' then
            req.clear_header(k)
          end
        end

        if ngx.ctx.headers then
          for k,v in pairs(ngx.ctx.headers) do
            req.set_header(k, v)
          end
        end
      ";

      proxy_http_version 1.1;
      proxy_pass $_url;
      resolver 8.8.8.8;
    }
  }
