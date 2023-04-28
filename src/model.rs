use super::schema::votes;
use diesel::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Queryable, Serialize)]
pub struct Vote {
    pub vote_id: i32,
    pub vote_value: String,
}

#[derive(Deserialize, Insertable, Serialize)]
#[diesel(table_name=votes)]
pub struct NewVote {
    pub vote_value: String,
}
