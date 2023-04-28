#[macro_use]
extern crate lazy_static;

mod database;
mod model;
mod schema;
use crate::schema::votes::vote_value;
use actix_files::Files;
use actix_web::{middleware::Logger, post, web, App, HttpResponse, HttpServer};
use database::setup;
use diesel::{dsl::*, pg::PgConnection, prelude::*, r2d2::ConnectionManager};
use env_logger::Env;
use handlebars::Handlebars;
use log::info;
use model::NewVote;
use r2d2::Pool;
use schema::votes::dsl::votes;
use serde::Deserialize;
use serde_json::json;
use std::env::var;
use std::fmt;
use std::sync::Mutex;


lazy_static! {
    static ref FIRST_VALUE: String = var("FIRST_VALUE").unwrap_or("Dogs".to_string());
    static ref SECOND_VALUE: String = var("SECOND_VALUE").unwrap_or("Cats".to_string());
}

#[derive(Debug, Deserialize)]
enum VoteValue {
    FirstValue,
    SecondValue,
    Reset,
}

impl fmt::Display for VoteValue {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            VoteValue::SecondValue => write!(f, "{}", *SECOND_VALUE),
            VoteValue::FirstValue => write!(f, "{}", *FIRST_VALUE),
            VoteValue::Reset => write!(f, "Reset"),
        }
    }
}

impl VoteValue {
    fn source_value(input: &str) -> VoteValue {
        if input == *FIRST_VALUE {
            return VoteValue::FirstValue
        }
        else if input == *SECOND_VALUE {
            return VoteValue::SecondValue
        }
        else if input == "Reset" {
            return VoteValue::Reset
        }
        else {
            panic!("Failed to match the vote type from {}", input);
        };
           
    }
}

#[derive(Deserialize)]
struct FormData {
    vote: String,
}

struct AppStateVoteCounter {
    first_value_counter: Mutex<i64>, // <- Mutex is necessary to mutate safely across threads
    second_value_counter: Mutex<i64>,
}

/// extract form data using serde
/// this handler gets called only if the content type is *x-www-form-urlencoded*
/// and the content of the request could be deserialized to a `FormData` struct
#[post("/")]
async fn submit(
    form: web::Form<FormData>,
    data: web::Data<AppStateVoteCounter>,
    pool: web::Data<Pool<ConnectionManager<PgConnection>>>,
    hb: web::Data<Handlebars<'_>>,
) -> HttpResponse {
    let mut first_value_counter = data.first_value_counter.lock().unwrap(); // <- get counter's MutexGuard
    let mut second_value_counter = data.second_value_counter.lock().unwrap();

    info!("Vote is: {}", &form.vote);
    info!("Debug Vote is: {:?}", &form.vote);
    
    let vote = VoteValue::source_value(&form.vote);

    match vote {
        VoteValue::FirstValue => *first_value_counter += 1, // <- access counter inside MutexGuard
        VoteValue::SecondValue => *second_value_counter += 1,
        VoteValue::Reset => {
            *first_value_counter = 0;
            *second_value_counter = 0;
        }
    }

    let data = json!({
        "title": "Azure Voting App",
        "button1": VoteValue::FirstValue.to_string(),
        "button2": VoteValue::SecondValue.to_string(),
        "value1": first_value_counter.to_string(),
        "value2": second_value_counter.to_string()
    });

    let body = hb.render("index", &data).unwrap();

    // if the vote value is not reset then save the
    if !matches!(vote, VoteValue::Reset) {
        let vote_data = NewVote {
            vote_value: form.vote.to_string(),
        };

        let mut connection = pool.get().unwrap();
        let _vote_data = web::block(move || {
            diesel::insert_into(votes)
                .values(vote_data)
                .execute(&mut connection)
        })
        .await;
    } else {
        let mut connection = pool.get().unwrap();
        let _vote_data = web::block(move || {
            let _ = diesel::delete(votes).execute(&mut connection);
        })
        .await;
    }

    HttpResponse::Ok().body(body)
}

async fn index(
    data: web::Data<AppStateVoteCounter>,
    hb: web::Data<Handlebars<'_>>,
) -> HttpResponse {
    let first_value_counter = data.first_value_counter.lock().unwrap(); // <- get counter's MutexGuard
    let second_value_counter = data.second_value_counter.lock().unwrap();

    info!("Value 1: {}", VoteValue::FirstValue);
    info!("Value 2: {}", VoteValue::SecondValue);

    let data = json!({
        "title": "Azure Voting App",
        "button1": VoteValue::FirstValue.to_string(),
        "button2": VoteValue::SecondValue.to_string(),
        "value1": first_value_counter.to_string(),
        "value2": second_value_counter.to_string()
    });
    let body = hb.render("index", &data).unwrap();
    HttpResponse::Ok().body(body)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Default logging format is:
    // %a %t "%r" %s %b "%{Referer}i" "%{User-Agent}i" %T
    env_logger::init_from_env(Env::default().default_filter_or("info"));

    let pool = setup();
    let mut connection = pool.get().unwrap();

    // Load up the dog votes
    let first_value_query = votes.filter(vote_value.eq(FIRST_VALUE.clone()));
    let first_value_result = first_value_query.select(count(vote_value)).first(&mut connection);
    let first_value_count = first_value_result.unwrap_or(0);

    // Load up the cat votes
    let second_value_query = votes.filter(vote_value.eq(SECOND_VALUE.clone()));
    let second_value_result = second_value_query.select(count(vote_value)).first(&mut connection);
    let second_value_count = second_value_result.unwrap_or(0);

    // Note: web::Data created _outside_ HttpServer::new closure
    let vote_counter = web::Data::new(AppStateVoteCounter {
        first_value_counter: Mutex::new(first_value_count),
        second_value_counter: Mutex::new(second_value_count),
    });

    let mut handlebars = Handlebars::new();
    handlebars
        .register_templates_directory(".html", "./static/")
        .unwrap();
    let handlebars_ref = web::Data::new(handlebars);

    info!("Listening on port 8080");
    HttpServer::new(move || {
        App::new()
            .wrap(Logger::default())
            // .wrap(Logger::new("%a %{User-Agent}i")) // <- optionally create your own format
            .app_data(vote_counter.clone()) // <- register the created data
            .app_data(handlebars_ref.clone())
            .data(pool.clone())
            .service(Files::new("/static", "static").show_files_listing())
            .route("/", web::get().to(index))
            .service(submit)
    })
    .bind(("0.0.0.0", 8080))?
    .run()
    .await
}
