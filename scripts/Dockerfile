FROM docker.elastic.co/logstash/logstash-oss:${LOGSTASH_VERSION:-7.13.2}
USER logstash
COPY --chown=logstash:logstash Gemfile /usr/share/plugins/plugin/Gemfile
COPY --chown=logstash:logstash *.gemspec VERSION* version* /usr/share/plugins/plugin/
RUN cp /usr/share/logstash/logstash-core/versions-gem-copy.yml /usr/share/logstash/versions.yml
ENV PATH="${PATH}:/usr/share/logstash/vendor/jruby/bin:/usr/share/logstash/jdk/bin"
ENV LOGSTASH_SOURCE="1"
ARG INTEGRATION
ENV INTEGRATION=$INTEGRATION
RUN gem install bundler -v '< 2'
WORKDIR /usr/share/plugins/plugin
RUN bundle install --with test ci
COPY --chown=logstash:logstash . /usr/share/plugins/plugin
RUN bundle exec rake vendor