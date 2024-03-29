import Foundation
import Combine

public final class NewsAPI {

    class URLRequestBuilder {
        private var url: URLComponents
        private var apiKey: String?

        init?(baseURL: URL, endpoint: Scope) {
            guard let validURL = URL(string: endpoint.rawValue, relativeTo: baseURL) else {
                return nil
            }
            self.url = URLComponents(url: validURL, resolvingAgainstBaseURL: true)!
            if url.queryItems == nil {
                url.queryItems = [URLQueryItem]()
            }
        }

        func apiKey(_ apiKey: String) -> Self {
            self.apiKey = apiKey
            return self
        }

        func country(iso3166 code: String) -> Self {
            if let index = url.queryItems!.firstIndex(where: { $0.value == code }) {
                url.queryItems![index] = URLQueryItem(name: "country", value: code)
            } else {
                url.queryItems!.append(URLQueryItem(name: "country", value: code))
            }
            return self
        }

        func category(_ category: String) -> Self {
            if let index = url.queryItems!.firstIndex(where: { $0.value == category }) {
                url.queryItems![index] = URLQueryItem(name: "category", value: category)
            } else {
                url.queryItems!.append(URLQueryItem(name: "category", value: category))
            }
            return self
        }

        func build() -> URLRequest {
            var request = URLRequest(url: self.url.url!.absoluteURL)
            if let apiKey = apiKey {
                request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            }
            return request
        }
    }

    let baseURL = URL(string: "https://newsapi.org/")!
    var apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public enum Scope: String {
        case topHeadlines = "/v2/top-headlines"
        case everything = "/v2/everything"
        case sources = "/v2/sources"
    }

    public typealias ArticleRequestCompletion = (Result<[Article],Error>) -> Void
    public typealias SourceRequestCompletion = (Result<[Source],Error>) -> Void

    private func buildRequest(scope: Scope) -> URLRequest {
        URLRequestBuilder(baseURL: baseURL, endpoint: scope)!
            .apiKey(apiKey)
            .country(iso3166: "se")
            .category("technology")
            .build()
    }

    public func articles(scope: Scope, country code: String? = Locale.current.regionCode, completion: @escaping ArticleRequestCompletion) {

        let task = URLSession.shared.dataTask(with: buildRequest(scope: scope)) { (data, response, error) in
            guard error == nil else {
                return completion(.failure(error!))
            }
            do {
                let response = try JSONDecoder().decode(NewsAPIResponse.self, from: data!)
                return completion(.success(response.articles))
            } catch {
                return completion(.failure(error))
            }
        }
        task.resume()
    }

    @available(iOS 13, *)
    public struct ArticlePublisher: Publisher {
        public func receive<S>(subscriber: S) where S : Subscriber, NewsAPI.ArticlePublisher.Failure == S.Failure, NewsAPI.ArticlePublisher.Output == S.Input {

        }

        public typealias Output = [Article]
        public typealias Failure = Never


    }
    class NewsAPIDecoder: JSONDecoder {
        override init() {
            super.init()
            if #available(iOS 10.0, *) {
                self.dateDecodingStrategy = .iso8601
            } else {
                // Fallback on earlier versions
            }
        }
    }

    @available(iOS 13, OSX 10.15, *)
    public func articles(scope: Scope) -> URLSession.DataTaskPublisher {
        URLSession.shared.dataTaskPublisher(for: buildRequest(scope: scope))
    }

    @available(iOS 13, *)
    public func articles(scope: Scope, countryCode: String) -> AnyPublisher<[Article],Error> {
        URLSession.shared.dataTaskPublisher(for: buildRequest(scope: scope))
            .map { $0.data }
            .decode(type: NewsAPIResponse.self, decoder: NewsAPIDecoder())
            .map { $0.articles }
            .eraseToAnyPublisher()
    }

    @available(iOS 13, *)
    public func articles(scope: Scope, countryCode: String, category: String) -> Any {
        URLSession.shared.dataTaskPublisher(for: buildRequest(scope: scope))
    }

}
