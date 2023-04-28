// @generated automatically by Diesel CLI.

diesel::table! {
    votes (vote_id) {
        vote_id -> Int4,
        vote_value -> Varchar,
    }
}
