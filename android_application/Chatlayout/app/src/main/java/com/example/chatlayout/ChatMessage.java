package com.example.chatlayout;

public class ChatMessage {
    public boolean left;
    public String message;
    public String from;
    public String to;

    public ChatMessage(boolean left, String message, String from, String to) {
        super();
        this.left = left;
        this.message = message;
        this.from = from;
        this.to = to;
    }
}