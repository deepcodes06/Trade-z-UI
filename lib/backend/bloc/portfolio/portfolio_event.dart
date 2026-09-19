sealed class PortfolioEvent {
  const PortfolioEvent();
}

class PortfolioLoadRequested extends PortfolioEvent {
  const PortfolioLoadRequested();
}

class PortfolioRefreshRequested extends PortfolioEvent {
  const PortfolioRefreshRequested();
}
