#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# mllib_clustering.R: Provides methods for MLlib clustering algorithms integration

#' S4 class that represents a GaussianMixtureModel
#'
#' @param jobj a Java object reference to the backing Scala GaussianMixtureModel
#' @export
#' @note GaussianMixtureModel since 2.1.0
setClass("GaussianMixtureModel", representation(jobj = "jobj"))

#' S4 class that represents a KMeansModel
#'
#' @param jobj a Java object reference to the backing Scala KMeansModel
#' @export
#' @note KMeansModel since 2.0.0
setClass("KMeansModel", representation(jobj = "jobj"))

#' S4 class that represents an LDAModel
#'
#' @param jobj a Java object reference to the backing Scala LDAWrapper
#' @export
#' @note LDAModel since 2.1.0
setClass("LDAModel", representation(jobj = "jobj"))

#' Multivariate Gaussian Mixture Model (GMM)
#'
#' Fits multivariate gaussian mixture model against a Spark DataFrame, similarly to R's
#' mvnormalmixEM(). Users can call \code{summary} to print a summary of the fitted model,
#' \code{predict} to make predictions on new data, and \code{write.ml}/\code{read.ml}
#' to save/load fitted models.
#'
#' @param data a SparkDataFrame for training.
#' @param formula a symbolic description of the model to be fitted. Currently only a few formula
#'                operators are supported, including '~', '.', ':', '+', and '-'.
#'                Note that the response variable of formula is empty in spark.gaussianMixture.
#' @param k number of independent Gaussians in the mixture model.
#' @param maxIter maximum iteration number.
#' @param tol the convergence tolerance.
#' @param ... additional arguments passed to the method.
#' @aliases spark.gaussianMixture,SparkDataFrame,formula-method
#' @return \code{spark.gaussianMixture} returns a fitted multivariate gaussian mixture model.
#' @rdname spark.gaussianMixture
#' @name spark.gaussianMixture
#' @seealso mixtools: \url{https://cran.r-project.org/package=mixtools}
#' @export
#' @examples
#' \dontrun{
#' sparkR.session()
#' library(mvtnorm)
#' set.seed(100)
#' a <- rmvnorm(4, c(0, 0))
#' b <- rmvnorm(6, c(3, 4))
#' data <- rbind(a, b)
#' df <- createDataFrame(as.data.frame(data))
#' model <- spark.gaussianMixture(df, ~ V1 + V2, k = 2)
#' summary(model)
#'
#' # fitted values on training data
#' fitted <- predict(model, df)
#' head(select(fitted, "V1", "prediction"))
#'
#' # save fitted model to input path
#' path <- "path/to/model"
#' write.ml(model, path)
#'
#' # can also read back the saved model and print
#' savedModel <- read.ml(path)
#' summary(savedModel)
#' }
#' @note spark.gaussianMixture since 2.1.0
#' @seealso \link{predict}, \link{read.ml}, \link{write.ml}
setMethod("spark.gaussianMixture", signature(data = "SparkDataFrame", formula = "formula"),
          function(data, formula, k = 2, maxIter = 100, tol = 0.01) {
            formula <- paste(deparse(formula), collapse = "")
            jobj <- callJStatic("org.apache.spark.ml.r.GaussianMixtureWrapper", "fit", data@sdf,
                                formula, as.integer(k), as.integer(maxIter), as.numeric(tol))
            new("GaussianMixtureModel", jobj = jobj)
          })

#  Get the summary of a multivariate gaussian mixture model

#' @param object a fitted gaussian mixture model.
#' @return \code{summary} returns summary of the fitted model, which is a list.
#'         The list includes the model's \code{lambda} (lambda), \code{mu} (mu),
#'         \code{sigma} (sigma), and \code{posterior} (posterior).
#' @aliases spark.gaussianMixture,SparkDataFrame,formula-method
#' @rdname spark.gaussianMixture
#' @export
#' @note summary(GaussianMixtureModel) since 2.1.0
setMethod("summary", signature(object = "GaussianMixtureModel"),
          function(object) {
            jobj <- object@jobj
            is.loaded <- callJMethod(jobj, "isLoaded")
            lambda <- unlist(callJMethod(jobj, "lambda"))
            muList <- callJMethod(jobj, "mu")
            sigmaList <- callJMethod(jobj, "sigma")
            k <- callJMethod(jobj, "k")
            dim <- callJMethod(jobj, "dim")
            mu <- c()
            for (i in 1 : k) {
              start <- (i - 1) * dim + 1
              end <- i * dim
              mu[[i]] <- unlist(muList[start : end])
            }
            sigma <- c()
            for (i in 1 : k) {
              start <- (i - 1) * dim * dim + 1
              end <- i * dim * dim
              sigma[[i]] <- t(matrix(sigmaList[start : end], ncol = dim))
            }
            posterior <- if (is.loaded) {
              NULL
            } else {
              dataFrame(callJMethod(jobj, "posterior"))
            }
            list(lambda = lambda, mu = mu, sigma = sigma,
                 posterior = posterior, is.loaded = is.loaded)
          })

#  Predicted values based on a gaussian mixture model

#' @param newData a SparkDataFrame for testing.
#' @return \code{predict} returns a SparkDataFrame containing predicted labels in a column named
#'         "prediction".
#' @aliases predict,GaussianMixtureModel,SparkDataFrame-method
#' @rdname spark.gaussianMixture
#' @export
#' @note predict(GaussianMixtureModel) since 2.1.0
setMethod("predict", signature(object = "GaussianMixtureModel"),
          function(object, newData) {
            predict_internal(object, newData)
          })

#  Save fitted MLlib model to the input path

#' @param path the directory where the model is saved.
#' @param overwrite overwrites or not if the output path already exists. Default is FALSE
#'                  which means throw exception if the output path exists.
#'
#' @aliases write.ml,GaussianMixtureModel,character-method
#' @rdname spark.gaussianMixture
#' @export
#' @note write.ml(GaussianMixtureModel, character) since 2.1.0
setMethod("write.ml", signature(object = "GaussianMixtureModel", path = "character"),
          function(object, path, overwrite = FALSE) {
            write_internal(object, path, overwrite)
          })

#' K-Means Clustering Model
#'
#' Fits a k-means clustering model against a Spark DataFrame, similarly to R's kmeans().
#' Users can call \code{summary} to print a summary of the fitted model, \code{predict} to make
#' predictions on new data, and \code{write.ml}/\code{read.ml} to save/load fitted models.
#'
#' @param data a SparkDataFrame for training.
#' @param formula a symbolic description of the model to be fitted. Currently only a few formula
#'                operators are supported, including '~', '.', ':', '+', and '-'.
#'                Note that the response variable of formula is empty in spark.kmeans.
#' @param k number of centers.
#' @param maxIter maximum iteration number.
#' @param initMode the initialization algorithm choosen to fit the model.
#' @param seed the random seed for cluster initialization.
#' @param initSteps the number of steps for the k-means|| initialization mode.
#'                  This is an advanced setting, the default of 2 is almost always enough. Must be > 0.
#' @param tol convergence tolerance of iterations.
#' @param ... additional argument(s) passed to the method.
#' @return \code{spark.kmeans} returns a fitted k-means model.
#' @rdname spark.kmeans
#' @aliases spark.kmeans,SparkDataFrame,formula-method
#' @name spark.kmeans
#' @export
#' @examples
#' \dontrun{
#' sparkR.session()
#' data(iris)
#' df <- createDataFrame(iris)
#' model <- spark.kmeans(df, Sepal_Length ~ Sepal_Width, k = 4, initMode = "random")
#' summary(model)
#'
#' # fitted values on training data
#' fitted <- predict(model, df)
#' head(select(fitted, "Sepal_Length", "prediction"))
#'
#' # save fitted model to input path
#' path <- "path/to/model"
#' write.ml(model, path)
#'
#' # can also read back the saved model and print
#' savedModel <- read.ml(path)
#' summary(savedModel)
#' }
#' @note spark.kmeans since 2.0.0
#' @seealso \link{predict}, \link{read.ml}, \link{write.ml}
setMethod("spark.kmeans", signature(data = "SparkDataFrame", formula = "formula"),
          function(data, formula, k = 2, maxIter = 20, initMode = c("k-means||", "random"),
                   seed = NULL, initSteps = 2, tol = 1E-4) {
            formula <- paste(deparse(formula), collapse = "")
            initMode <- match.arg(initMode)
            if (!is.null(seed)) {
              seed <- as.character(as.integer(seed))
            }
            jobj <- callJStatic("org.apache.spark.ml.r.KMeansWrapper", "fit", data@sdf, formula,
                                as.integer(k), as.integer(maxIter), initMode, seed,
                                as.integer(initSteps), as.numeric(tol))
            new("KMeansModel", jobj = jobj)
          })

#  Get the summary of a k-means model

#' @param object a fitted k-means model.
#' @return \code{summary} returns summary information of the fitted model, which is a list.
#'         The list includes the model's \code{k} (number of cluster centers),
#'         \code{coefficients} (model cluster centers),
#'         \code{size} (number of data points in each cluster), and \code{cluster}
#'         (cluster centers of the transformed data).
#' @rdname spark.kmeans
#' @export
#' @note summary(KMeansModel) since 2.0.0
setMethod("summary", signature(object = "KMeansModel"),
          function(object) {
            jobj <- object@jobj
            is.loaded <- callJMethod(jobj, "isLoaded")
            features <- callJMethod(jobj, "features")
            coefficients <- callJMethod(jobj, "coefficients")
            k <- callJMethod(jobj, "k")
            size <- callJMethod(jobj, "size")
            coefficients <- t(matrix(coefficients, ncol = k))
            colnames(coefficients) <- unlist(features)
            rownames(coefficients) <- 1:k
            cluster <- if (is.loaded) {
              NULL
            } else {
              dataFrame(callJMethod(jobj, "cluster"))
            }
            list(k = k, coefficients = coefficients, size = size,
                 cluster = cluster, is.loaded = is.loaded)
          })

#  Predicted values based on a k-means model

#' @param newData a SparkDataFrame for testing.
#' @return \code{predict} returns the predicted values based on a k-means model.
#' @rdname spark.kmeans
#' @export
#' @note predict(KMeansModel) since 2.0.0
setMethod("predict", signature(object = "KMeansModel"),
          function(object, newData) {
            predict_internal(object, newData)
          })

#' Get fitted result from a k-means model
#'
#' Get fitted result from a k-means model, similarly to R's fitted().
#' Note: A saved-loaded model does not support this method.
#'
#' @param object a fitted k-means model.
#' @param method type of fitted results, \code{"centers"} for cluster centers
#'        or \code{"classes"} for assigned classes.
#' @param ... additional argument(s) passed to the method.
#' @return \code{fitted} returns a SparkDataFrame containing fitted values.
#' @rdname fitted
#' @export
#' @examples
#' \dontrun{
#' model <- spark.kmeans(trainingData, ~ ., 2)
#' fitted.model <- fitted(model)
#' showDF(fitted.model)
#'}
#' @note fitted since 2.0.0
setMethod("fitted", signature(object = "KMeansModel"),
          function(object, method = c("centers", "classes")) {
            method <- match.arg(method)
            jobj <- object@jobj
            is.loaded <- callJMethod(jobj, "isLoaded")
            if (is.loaded) {
              stop("Saved-loaded k-means model does not support 'fitted' method")
            } else {
              dataFrame(callJMethod(jobj, "fitted", method))
            }
          })

#  Save fitted MLlib model to the input path

#' @param path the directory where the model is saved.
#' @param overwrite overwrites or not if the output path already exists. Default is FALSE
#'                  which means throw exception if the output path exists.
#'
#' @rdname spark.kmeans
#' @export
#' @note write.ml(KMeansModel, character) since 2.0.0
setMethod("write.ml", signature(object = "KMeansModel", path = "character"),
          function(object, path, overwrite = FALSE) {
            write_internal(object, path, overwrite)
          })

#' Latent Dirichlet Allocation
#'
#' \code{spark.lda} fits a Latent Dirichlet Allocation model on a SparkDataFrame. Users can call
#' \code{summary} to get a summary of the fitted LDA model, \code{spark.posterior} to compute
#' posterior probabilities on new data, \code{spark.perplexity} to compute log perplexity on new
#' data and \code{write.ml}/\code{read.ml} to save/load fitted models.
#'
#' @param data A SparkDataFrame for training.
#' @param features Features column name. Either libSVM-format column or character-format column is
#'        valid.
#' @param k Number of topics.
#' @param maxIter Maximum iterations.
#' @param optimizer Optimizer to train an LDA model, "online" or "em", default is "online".
#' @param subsamplingRate (For online optimizer) Fraction of the corpus to be sampled and used in
#'        each iteration of mini-batch gradient descent, in range (0, 1].
#' @param topicConcentration concentration parameter (commonly named \code{beta} or \code{eta}) for
#'        the prior placed on topic distributions over terms, default -1 to set automatically on the
#'        Spark side. Use \code{summary} to retrieve the effective topicConcentration. Only 1-size
#'        numeric is accepted.
#' @param docConcentration concentration parameter (commonly named \code{alpha}) for the
#'        prior placed on documents distributions over topics (\code{theta}), default -1 to set
#'        automatically on the Spark side. Use \code{summary} to retrieve the effective
#'        docConcentration. Only 1-size or \code{k}-size numeric is accepted.
#' @param customizedStopWords stopwords that need to be removed from the given corpus. Ignore the
#'        parameter if libSVM-format column is used as the features column.
#' @param maxVocabSize maximum vocabulary size, default 1 << 18
#' @param ... additional argument(s) passed to the method.
#' @return \code{spark.lda} returns a fitted Latent Dirichlet Allocation model.
#' @rdname spark.lda
#' @aliases spark.lda,SparkDataFrame-method
#' @seealso topicmodels: \url{https://cran.r-project.org/package=topicmodels}
#' @export
#' @examples
#' \dontrun{
#' # nolint start
#' # An example "path/to/file" can be
#' # paste0(Sys.getenv("SPARK_HOME"), "/data/mllib/sample_lda_libsvm_data.txt")
#' # nolint end
#' text <- read.df("path/to/file", source = "libsvm")
#' model <- spark.lda(data = text, optimizer = "em")
#'
#' # get a summary of the model
#' summary(model)
#'
#' # compute posterior probabilities
#' posterior <- spark.posterior(model, text)
#' showDF(posterior)
#'
#' # compute perplexity
#' perplexity <- spark.perplexity(model, text)
#'
#' # save and load the model
#' path <- "path/to/model"
#' write.ml(model, path)
#' savedModel <- read.ml(path)
#' summary(savedModel)
#' }
#' @note spark.lda since 2.1.0
setMethod("spark.lda", signature(data = "SparkDataFrame"),
          function(data, features = "features", k = 10, maxIter = 20, optimizer = c("online", "em"),
                   subsamplingRate = 0.05, topicConcentration = -1, docConcentration = -1,
                   customizedStopWords = "", maxVocabSize = bitwShiftL(1, 18)) {
            optimizer <- match.arg(optimizer)
            jobj <- callJStatic("org.apache.spark.ml.r.LDAWrapper", "fit", data@sdf, features,
                                as.integer(k), as.integer(maxIter), optimizer,
                                as.numeric(subsamplingRate), topicConcentration,
                                as.array(docConcentration), as.array(customizedStopWords),
                                maxVocabSize)
            new("LDAModel", jobj = jobj)
          })

#  Returns the summary of a Latent Dirichlet Allocation model produced by \code{spark.lda}

#' @param object A Latent Dirichlet Allocation model fitted by \code{spark.lda}.
#' @param maxTermsPerTopic Maximum number of terms to collect for each topic. Default value of 10.
#' @return \code{summary} returns summary information of the fitted model, which is a list.
#'         The list includes
#'         \item{\code{docConcentration}}{concentration parameter commonly named \code{alpha} for
#'               the prior placed on documents distributions over topics \code{theta}}
#'         \item{\code{topicConcentration}}{concentration parameter commonly named \code{beta} or
#'               \code{eta} for the prior placed on topic distributions over terms}
#'         \item{\code{logLikelihood}}{log likelihood of the entire corpus}
#'         \item{\code{logPerplexity}}{log perplexity}
#'         \item{\code{isDistributed}}{TRUE for distributed model while FALSE for local model}
#'         \item{\code{vocabSize}}{number of terms in the corpus}
#'         \item{\code{topics}}{top 10 terms and their weights of all topics}
#'         \item{\code{vocabulary}}{whole terms of the training corpus, NULL if libsvm format file
#'               used as training set}
#' @rdname spark.lda
#' @aliases summary,LDAModel-method
#' @export
#' @note summary(LDAModel) since 2.1.0
setMethod("summary", signature(object = "LDAModel"),
          function(object, maxTermsPerTopic) {
            maxTermsPerTopic <- as.integer(ifelse(missing(maxTermsPerTopic), 10, maxTermsPerTopic))
            jobj <- object@jobj
            docConcentration <- callJMethod(jobj, "docConcentration")
            topicConcentration <- callJMethod(jobj, "topicConcentration")
            logLikelihood <- callJMethod(jobj, "logLikelihood")
            logPerplexity <- callJMethod(jobj, "logPerplexity")
            isDistributed <- callJMethod(jobj, "isDistributed")
            vocabSize <- callJMethod(jobj, "vocabSize")
            topics <- dataFrame(callJMethod(jobj, "topics", maxTermsPerTopic))
            vocabulary <- callJMethod(jobj, "vocabulary")
            list(docConcentration = unlist(docConcentration),
                 topicConcentration = topicConcentration,
                 logLikelihood = logLikelihood, logPerplexity = logPerplexity,
                 isDistributed = isDistributed, vocabSize = vocabSize,
                 topics = topics, vocabulary = unlist(vocabulary))
          })

#  Returns the log perplexity of a Latent Dirichlet Allocation model produced by \code{spark.lda}

#' @return \code{spark.perplexity} returns the log perplexity of given SparkDataFrame, or the log
#'         perplexity of the training data if missing argument "data".
#' @rdname spark.lda
#' @aliases spark.perplexity,LDAModel-method
#' @export
#' @note spark.perplexity(LDAModel) since 2.1.0
setMethod("spark.perplexity", signature(object = "LDAModel", data = "SparkDataFrame"),
          function(object, data) {
            ifelse(missing(data), callJMethod(object@jobj, "logPerplexity"),
                   callJMethod(object@jobj, "computeLogPerplexity", data@sdf))
         })

#  Returns posterior probabilities from a Latent Dirichlet Allocation model produced by spark.lda()

#' @param newData A SparkDataFrame for testing.
#' @return \code{spark.posterior} returns a SparkDataFrame containing posterior probabilities
#'         vectors named "topicDistribution".
#' @rdname spark.lda
#' @aliases spark.posterior,LDAModel,SparkDataFrame-method
#' @export
#' @note spark.posterior(LDAModel) since 2.1.0
setMethod("spark.posterior", signature(object = "LDAModel", newData = "SparkDataFrame"),
          function(object, newData) {
            predict_internal(object, newData)
          })

#  Saves the Latent Dirichlet Allocation model to the input path.

#' @param path The directory where the model is saved.
#' @param overwrite Overwrites or not if the output path already exists. Default is FALSE
#'                  which means throw exception if the output path exists.
#'
#' @rdname spark.lda
#' @aliases write.ml,LDAModel,character-method
#' @export
#' @seealso \link{read.ml}
#' @note write.ml(LDAModel, character) since 2.1.0
setMethod("write.ml", signature(object = "LDAModel", path = "character"),
          function(object, path, overwrite = FALSE) {
            write_internal(object, path, overwrite)
          })
