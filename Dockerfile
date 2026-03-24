FROM ruby:3.3-slim

RUN apt-get update -qq && apt-get install -y build-essential libsqlite3-dev nodejs

WORKDIR /myapp

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN chmod -R 755 /storage

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
